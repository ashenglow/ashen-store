package ashen.store.outbox;
import org.springframework.data.jpa.repository.*;
import java.util.*;
public interface OutboxRepository extends JpaRepository<Outbox,Long>{ List<Outbox> findByOrderByCreatedAtAsc(); }
