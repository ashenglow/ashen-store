package ashen.store.serializer;

import com.fasterxml.jackson.databind.*; import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

public class DataSerializer {
  private static final ObjectMapper M;
  static { M = new ObjectMapper(); M.registerModule(new JavaTimeModule()); M.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS); }
  public static String serialize(Object o){ try { return M.writeValueAsString(o); } catch(Exception e){ throw new RuntimeException(e); } }
  public static <T> T deserialize(String json, Class<T> t){ try { return M.readValue(json, t); } catch(Exception e){ throw new RuntimeException(e); } }
}
