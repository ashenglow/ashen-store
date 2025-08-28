package ashen.store.snowflake;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "snowflake")
public class SnowflakeIdGenerator {
  private final long nodeId = 1L;
  private long seq=0L;
  private long last=-1L;
  public synchronized long nextId(){
    long now = System.currentTimeMillis();
    if (now==last){ seq=(seq+1)&0xFFF; if (seq==0) while((now=System.currentTimeMillis())==last){} }
    else seq=0;
    last=now;
    return (now<<22) | (nodeId<<12) | seq;
  }
}
