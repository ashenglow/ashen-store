package ashen.store.member.domain;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name="members", indexes = { @Index(name="idx_member_user_id", columnList="userId", unique=true) })
public class Member {
  @Id
  @GeneratedValue(strategy=GenerationType.IDENTITY)
  private Long id;
  @Column(nullable=false, unique=true)
  private String userId;
  private String name;
  private String email;
  private Instant createdAt = Instant.now();
  protected Member(){}
  public Member(String userId, String name, String email){
    this.userId=userId;
    this.name=name;
    this.email=email;
  }
  public Long getId(){
    return id;
  }
  public String getUserId(){
    return userId;
  }
  public String getName(){
    return name;
  }
}
