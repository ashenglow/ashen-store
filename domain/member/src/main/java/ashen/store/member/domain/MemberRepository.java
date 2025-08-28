package ashen.store.member.domain;
import java.util.*;
public interface MemberRepository{
    Optional<Member> findById(Long id);
    Member save(Member m);
}
