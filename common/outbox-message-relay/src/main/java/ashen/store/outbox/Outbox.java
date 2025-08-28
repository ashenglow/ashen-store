package ashen.store.outbox;

import jakarta.persistence.*;
import java.time.Instant; import ashen.store.serializer.DataSerializer;

@Entity @Table(name="outbox")
public class Outbox {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  private String typeFqcn; @Lob private String payloadJson; private Instant createdAt = Instant.now();
  protected Outbox(){}
  public Outbox(Object payload){ this.typeFqcn=payload.getClass().getName(); this.payloadJson=DataSerializer.serialize(payload); }
  public Long getId(){ return id; } public String getTypeFqcn(){ return typeFqcn; } public String getPayloadJson(){ return payloadJson; }
}
