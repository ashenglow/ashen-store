package ashen.store.outbox;

import org.springframework.kafka.core.KafkaTemplate; import org.springframework.scheduling.annotation.Scheduled; import org.springframework.stereotype.Component;
import java.util.*; import java.util.concurrent.TimeUnit; import ashen.store.event.Topic;

@Component
public class OutboxRelayService {
  private final OutboxRepository repo; private final KafkaTemplate<String,String> kafka;
  public OutboxRelayService(OutboxRepository r, KafkaTemplate<String,String> k){ this.repo=r; this.kafka=k; }

  @Scheduled(fixedDelay=5000)
  public void relay(){
    List<Outbox> events = repo.findByOrderByCreatedAtAsc();
    for (Outbox o: events){
      try{
        Class<?> clz = Class.forName(o.getTypeFqcn());
        Topic t = clz.getAnnotation(Topic.class);
        String topic = (t!=null? t.value() : "default-topic");
        kafka.send(topic, o.getPayloadJson()).get(1, TimeUnit.SECONDS);
        repo.delete(o);
      } catch(Exception e){
        // TODO: DLQ persist; for now just keep it for retry on next run
      }
    }
  }
}
