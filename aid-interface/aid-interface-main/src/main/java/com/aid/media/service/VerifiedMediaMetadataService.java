package com.aid.media.service;

import com.aid.common.aid.oss.util.MediaUrlResolver;
import com.aid.common.error.TaskErrorCode;
import com.aid.common.error.TaskErrorPresentation;
import com.aid.common.exception.ServiceException;
import com.aid.compose.config.MpsConfigManager;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.HttpURLConnection;
import java.net.URI;
import java.net.SocketTimeoutException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.TimeUnit;

/** 从受信任对象存储读取完整媒体并在无网络探测器中取得校验元数据。 */
@Service
@RequiredArgsConstructor
@Slf4j
public class VerifiedMediaMetadataService {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final long MAX_BYTES = 512L * 1024 * 1024;
    private static final int DOWNLOAD_ATTEMPTS = 2;
    private static final int CONNECT_TIMEOUT_MILLIS = 5_000;
    private static final int READ_TIMEOUT_MILLIS = 5_000;
    private static final long DOWNLOAD_TIMEOUT_SECONDS = 30;
    private final MediaUrlResolver urls;
    private final MpsConfigManager config;

    public Metadata inspect(String source, String kind) {
        Path file = null;
        Process process = null;
        HttpURLConnection connection = null;
        try {
            if (!urls.isSiteImageUrl(source)) throw new ServiceException("请使用本站素材");
            String originalAddress = urls.toFullUrl(source);
            long size = 0;
            for (int attempt = 1; attempt <= DOWNLOAD_ATTEMPTS; attempt++) {
                String address = originalAddress;
                try {
                    for (int hop = 0; ; hop++) {
                        URI uri = URI.create(address);
                        if (!urls.isSiteImageUrl(address) || !Set.of("http", "https").contains(uri.getScheme())
                                || uri.getHost() == null || uri.getUserInfo() != null || uri.getFragment() != null) {
                            throw new ServiceException("素材地址不可用");
                        }
                        connection = (HttpURLConnection) uri.toURL().openConnection();
                        connection.setInstanceFollowRedirects(false);
                        connection.setConnectTimeout(CONNECT_TIMEOUT_MILLIS);
                        connection.setReadTimeout(READ_TIMEOUT_MILLIS);
                        int status = connection.getResponseCode();
                        if (status >= 300 && status < 400) {
                            String location = connection.getHeaderField("Location");
                            connection.disconnect();
                            connection = null;
                            if (location == null || hop >= 3) throw new ServiceException("素材跳转无效");
                            address = uri.resolve(location).toString();
                            continue;
                        }
                        if (status != 200) throw new ServiceException("素材文件不可用");
                        break;
                    }
                    if (connection.getContentLengthLong() > MAX_BYTES) throw new ServiceException("素材文件过大");
                    file = Files.createTempFile("aid-input-metadata-", ".bin");
                    size = 0;
                    long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(DOWNLOAD_TIMEOUT_SECONDS);
                    try (InputStream input = connection.getInputStream(); OutputStream output = Files.newOutputStream(file)) {
                        byte[] buffer = new byte[65536];
                        int count;
                        while ((count = input.read(buffer)) != -1) {
                            size += count;
                            if (size > MAX_BYTES) throw new ServiceException("素材文件过大");
                            if (System.nanoTime() > deadline) throw new SocketTimeoutException("media download deadline exceeded");
                            output.write(buffer, 0, count);
                        }
                    }
                    if (size == 0) throw new ServiceException("素材文件为空");
                    break;
                } catch (SocketTimeoutException ex) {
                    if (connection != null) {
                        connection.disconnect();
                        connection = null;
                    }
                    if (file != null) {
                        try {
                            Files.deleteIfExists(file);
                        } catch (Exception cleanupError) {
                            log.warn("输入素材读取重试前临时文件待清理: {}", file);
                        }
                        file = null;
                    }
                    if (attempt >= DOWNLOAD_ATTEMPTS) throw ex;
                    log.warn("输入素材读取超时，执行有限重试: host={}, kind={}, attempt={}/{}",
                            safeHost(address), kind, attempt, DOWNLOAD_ATTEMPTS);
                }
            }
            java.util.List<String> command = new java.util.ArrayList<>(java.util.List.of(
                    config.getMpsProperties().getFfprobePath(), "-v", "error", "-protocol_whitelist", "file,pipe",
                    "-select_streams", "audio".equals(kind) ? "a:0" : "v:0"));
            if ("image".equals(kind)) command.add("-count_frames");
            command.addAll(java.util.List.of("-show_entries",
                    "stream=codec_name,width,height,avg_frame_rate,duration,nb_read_frames:format=duration,format_name:format_tags=major_brand",
                    "-of", "json", file.toString()));
            process = new ProcessBuilder(command).redirectErrorStream(true).start();
            if (!process.waitFor(8, TimeUnit.SECONDS) || process.exitValue() != 0) throw new ServiceException("素材解析失败");
            byte[] response = process.getInputStream().readNBytes(65537);
            if (response.length > 65536) throw new ServiceException("素材解析失败");
            JsonNode root = JSON.readTree(response);
            JsonNode stream = root.path("streams").path(0);
            if (!stream.isObject()) throw new ServiceException("素材类型不匹配");
            BigDecimal duration = positiveDecimal(stream.path("duration").asText());
            if (duration == null) duration = positiveDecimal(root.path("format").path("duration").asText());
            if (!"image".equals(kind) && (duration == null || duration.signum() <= 0)) throw new ServiceException("素材时长不可用");
            BigDecimal fps = null;
            String[] fraction = stream.path("avg_frame_rate").asText().split("/");
            if (fraction.length == 2 && !"0".equals(fraction[1])) {
                fps = new BigDecimal(fraction[0]).divide(new BigDecimal(fraction[1]), 12, RoundingMode.HALF_UP);
            }
            return new Metadata(size, duration, stream.path("width").asInt(0), stream.path("height").asInt(0), fps,
                    format(kind, stream.path("codec_name").asText(), root.path("format"), file),
                    stream.path("codec_name").asText(), stream.path("nb_read_frames").asInt(0));
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new ServiceException("素材解析中断");
        } catch (SocketTimeoutException ex) {
            throw TaskErrorPresentation.fromCode(
                    TaskErrorCode.USER_FILE_DOWNLOAD_FAILED, "素材读取超时，请重试");
        } catch (ServiceException ex) { throw ex; }
        catch (Exception ex) {
            log.info("输入素材元数据不可用: {}", ex.getClass().getSimpleName());
            throw new ServiceException("素材元数据不可用");
        } finally {
            if (connection != null) connection.disconnect();
            if (process != null && process.isAlive()) process.destroyForcibly();
            if (file != null) {
                try { Files.deleteIfExists(file); }
                catch (Exception ex) { log.warn("输入素材探测临时文件待清理: {}", file); }
            }
        }
    }

    private static String safeHost(String address) {
        try {
            return URI.create(address).getHost();
        } catch (Exception ignored) {
            return "unknown";
        }
    }

    private static BigDecimal positiveDecimal(String value) {
        try {
            BigDecimal number = new BigDecimal(value);
            return number.signum() > 0 ? number : null;
        } catch (NumberFormatException ignored) {
            return null;
        }
    }

    private String format(String kind, String codec, JsonNode container, Path file) {
        String format = container.path("format_name").asText().toLowerCase(Locale.ROOT);
        String brand = container.path("tags").path("major_brand").asText().trim().toLowerCase(Locale.ROOT);
        if ("image".equals(kind) && "hevc".equals(codec)
                && Set.of("heic", "heix", "hevc", "hevx", "mif1", "msf1").contains(brand)) return "heif";
        if ("image".equals(kind) && (format.contains("mov") || format.contains("avi")
                || format.contains("matroska") || format.contains("mpegts") || format.contains("flv"))) {
            throw new ServiceException("素材类型不匹配");
        }
        if ("image".equals(kind)) return switch (codec) {
            case "mjpeg" -> {
                if (format.contains("mov") || format.contains("avi")) throw new ServiceException("素材类型不匹配");
                yield "jpeg";
            }
            case "jpeg2000" -> "jp2";
            case "tiff" -> "tiff";
            case "png", "webp", "bmp", "gif", "apng" -> codec;
            default -> throw new ServiceException("素材格式未识别");
        };
        if (format.contains("mov")) return "audio".equals(kind) ? "m4a" : "qt".equals(brand) ? "mov" : "mp4";
        if (format.contains("matroska") || format.contains("webm")) {
            String docType = detectEbmlDocType(file);
            if ("webm".equals(docType)) return "webm";
            if ("matroska".equals(docType)) return "mkv";
            throw new ServiceException("素材格式未识别");
        }
        if (format.contains("mp3")) return "mp3";
        return format.split(",")[0];
    }

    /** 只解析 EBML Header 内的 DocType，不能用 ffprobe 的联合 demuxer 名猜测 WebM。 */
    static String detectEbmlDocType(Path file) {
        if (file == null) return null;
        try (InputStream input = Files.newInputStream(file)) {
            byte[] bytes = input.readNBytes(65_536);
            if (bytes.length < 6 || (bytes[0] & 0xff) != 0x1a || (bytes[1] & 0xff) != 0x45
                    || (bytes[2] & 0xff) != 0xdf || (bytes[3] & 0xff) != 0xa3) return null;
            Vint headerSize = readEbmlVint(bytes, 4, true);
            if (headerSize == null || headerSize.unknown()) return null;
            long headerEndValue = 4L + headerSize.length() + headerSize.value();
            if (headerEndValue > bytes.length || headerEndValue > Integer.MAX_VALUE) return null;
            int offset = 4 + headerSize.length();
            int end = (int) headerEndValue;
            while (offset < end) {
                Vint id = readEbmlVint(bytes, offset, false);
                if (id == null) return null;
                offset += id.length();
                Vint size = readEbmlVint(bytes, offset, true);
                if (size == null || size.unknown() || size.value() > end - offset - size.length()) return null;
                offset += size.length();
                int valueLength = (int) size.value();
                if (id.value() == 0x4282L) {
                    if (valueLength <= 0 || valueLength > 32) return null;
                    return new String(bytes, offset, valueLength, StandardCharsets.US_ASCII)
                            .trim().toLowerCase(Locale.ROOT);
                }
                offset += valueLength;
            }
            return null;
        } catch (Exception ignored) {
            return null;
        }
    }

    private static Vint readEbmlVint(byte[] bytes, int offset, boolean size) {
        if (bytes == null || offset < 0 || offset >= bytes.length) return null;
        int first = bytes[offset] & 0xff;
        int length = 1;
        int mask = 0x80;
        while (length <= 8 && (first & mask) == 0) {
            length++;
            mask >>>= 1;
        }
        if (length > 8 || offset + length > bytes.length || !size && length > 4) return null;
        long value = size ? first & (mask - 1L) : first;
        for (int index = 1; index < length; index++) value = value << 8 | bytes[offset + index] & 0xffL;
        boolean unknown = size && value == (1L << (7 * length)) - 1L;
        return new Vint(value, length, unknown);
    }

    private record Vint(long value, int length, boolean unknown) { }

    public record Metadata(long sizeBytes, BigDecimal durationSeconds, int width, int height, BigDecimal fps,
                           String format, String codec, int frameCount) { }
}
