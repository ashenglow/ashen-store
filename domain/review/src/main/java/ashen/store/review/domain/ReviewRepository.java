package ashen.store.review.domain;
import java.util.*;
import java.util.UUID;
public interface ReviewRepository{
    Review save(Review r); List<Review> findByProductId(Long productId);
}
