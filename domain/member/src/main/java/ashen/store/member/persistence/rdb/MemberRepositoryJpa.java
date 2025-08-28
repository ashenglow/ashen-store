package ashen.store.member.persistence.rdb;
import ashen.store.member.domain.*;
import org.springframework.data.jpa.repository.JpaRepository;
public interface MemberRepositoryJpa extends MemberRepository, JpaRepository<Member,Long>{}
