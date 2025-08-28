package ashen.store.review.domain;

import jakarta.persistence.*; import java.util.UUID; import java.time.Instant;
@Entity
@Table(name="reviews", indexes = {
  @Index(name="idx_review_product_created", columnList="productId, createdAt DESC"),
  @Index(name="idx_review_member_created", columnList="memberId, createdAt DESC")
})
public class Review {
  @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
  private Long productId; private Long memberId; private String content; private int rating;
  private Instant createdAt = Instant.now();
  protected Review(){}
  public Review(Long productId, Long memberId, String content, int rating){
    this.productId=productId; this.memberId=memberId; this.content=content; this.rating=rating;
  }
  public UUID getId(){ return id; } public Long getProductId(){ return productId; } public Long getMemberId(){ return memberId; }
  public String getContent(){ return content; } public int getRating(){ return rating; }
}
