package ashen.store.inventory.domain;

import jakarta.persistence.*;

@Entity
@Table(name="inventory", indexes = { @Index(name="idx_inventory_product_id", columnList="productId", unique=true) })
public class Inventory {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  @Column(nullable=false, unique=true) private Long productId;
  private int quantity;
  @Version private int version;
  protected Inventory(){}
  public Inventory(Long productId,int quantity){ this.productId=productId; this.quantity=quantity; }
  public Long getProductId(){ return productId; } public int getQuantity(){ return quantity; }
  public void setQuantity(int q){ this.quantity=q; }
}
