package ashen.store.catalog.persistence;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

import java.net.URLDecoder;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.TreeMap;

@Converter(autoApply = false)
public class SkuOptionConverter implements AttributeConverter<Map<String, String>, String> {

    /** Map -> 정규키 (키 정렬, URL 인코딩, 빈맵은 DEFAULT) */
    public static String toKey(Map<String,String> attrs) {
        if (attrs == null || attrs.isEmpty()) return "DEFAULT";
        var sorted = new TreeMap<String,String>(String.CASE_INSENSITIVE_ORDER);
        attrs.forEach((k,v) -> {
            var key = k==null ? "" : k.trim();
            var val = v==null ? "" : v.trim();
            if (!key.isBlank()) sorted.put(key, val);
        });
        if (sorted.isEmpty()) return "DEFAULT";

        var sb = new StringBuilder();
        for (var e : sorted.entrySet()) {
            if (sb.length() > 0) sb.append('&');
            sb.append(enc(e.getKey())).append('=').append(enc(e.getValue()));
        }
        return sb.toString();
    }

    /** 정규키 -> Map */
    public static Map<String,String> toMap(String key) {
        if (key == null || "DEFAULT".equals(key)) return Map.of();
        var map = new LinkedHashMap<String,String>();
        for (String pair : key.split("&", -1)) {
            int i = pair.indexOf('=');
            String k = i < 0 ? pair : pair.substring(0, i);
            String v = i < 0 ? ""    : pair.substring(i + 1);
            map.put(dec(k), dec(v));
        }
        return map;
    }

    @Override public String convertToDatabaseColumn(Map<String,String> attribute) {
        return toKey(attribute);
    }

    @Override public Map<String,String> convertToEntityAttribute(String dbData) {
        return toMap(dbData);
    }

    private static String enc(String s){
        return URLEncoder.encode(s, StandardCharsets.UTF_8).replace("+","%20");
    }
    private static String dec(String s){
        return URLDecoder.decode(s, StandardCharsets.UTF_8);
    }
}
