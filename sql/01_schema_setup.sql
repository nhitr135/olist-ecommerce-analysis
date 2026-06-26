/*
  Project : Olist E-Commerce Data Analysis
  File     : 01_schema_setup.sql
  Purpose  : Define data types, primary keys and foreign keys for the
             9 raw tables imported from the Olist dataset (Kaggle).
            
  Author   : Tran Ngoc Nhi
  Date     : 2026-06
  */

USE Olist;
GO

/*- 1. Fix the category translation table
     The import wizard failed to read the header row of
     product_category_name_translation.csv, so the columns were named
     column1 / column2 and the original header was inserted as a data row.*/
EXEC sp_rename 'product_category_name_translation.column1', 'product_category_name',         'COLUMN';
EXEC sp_rename 'product_category_name_translation.column2', 'product_category_name_english', 'COLUMN';
GO

DELETE FROM product_category_name_translation
WHERE  product_category_name = 'product_category_name';
GO

/* 2. Primary keys
     Each key column is first set to NOT NULL (required for a PK),
     then the PRIMARY KEY constraint is added.*/

-- customers : one row per customer_id
ALTER TABLE customers ALTER COLUMN customer_id NVARCHAR(50) NOT NULL;
GO
ALTER TABLE customers ADD CONSTRAINT PK_customers PRIMARY KEY (customer_id);
GO

-- orders : one row per order_id
ALTER TABLE olist_orders_dataset ALTER COLUMN order_id NVARCHAR(50) NOT NULL;
GO
ALTER TABLE olist_orders_dataset ADD CONSTRAINT PK_orders PRIMARY KEY (order_id);
GO

-- products : one row per product_id
ALTER TABLE products ALTER COLUMN product_id NVARCHAR(50) NOT NULL;
GO
ALTER TABLE products ADD CONSTRAINT PK_products PRIMARY KEY (product_id);
GO

-- sellers : one row per seller_id
ALTER TABLE sellers ALTER COLUMN seller_id NVARCHAR(50) NOT NULL;
GO
ALTER TABLE sellers ADD CONSTRAINT PK_sellers PRIMARY KEY (seller_id);
GO

-- category translation : one row per Portuguese category name
ALTER TABLE product_category_name_translation
      ALTER COLUMN product_category_name NVARCHAR(100) NOT NULL;
GO
ALTER TABLE product_category_name_translation
      ADD CONSTRAINT PK_category PRIMARY KEY (product_category_name);
GO

/* Note:
   - order_items has a composite key (order_id, order_item_id) but is left without a PK because the foreign keys now are enough for analysis.
   - order_reviews can contain duplicate review_id values (a known issue in the raw Olist data), so no PK is enforced on it.
   - geolocation has many rows per zip code prefix, so no PK is needed.   */

/* Align column lengths before creating foreign keys
     A foreign key requires both columns to share the same data type and length. products.product_category_name is widened to match the category translation table; it stays NULL-able because some products have no category.*/
ALTER TABLE products ALTER COLUMN product_category_name NVARCHAR(100) NULL;
GO

/*
  3. Foreign keys */

-- orders.customer_id -> customers
ALTER TABLE olist_orders_dataset
      ADD CONSTRAINT FK_orders_customers
      FOREIGN KEY (customer_id) REFERENCES customers(customer_id);
GO

-- order_items.order_id -> orders
ALTER TABLE order_items
      ADD CONSTRAINT FK_items_orders
      FOREIGN KEY (order_id) REFERENCES olist_orders_dataset(order_id);
GO

-- order_items.product_id -> products
ALTER TABLE order_items
      ADD CONSTRAINT FK_items_products
      FOREIGN KEY (product_id) REFERENCES products(product_id);
GO

-- order_items.seller_id -> sellers
ALTER TABLE order_items
      ADD CONSTRAINT FK_items_sellers
      FOREIGN KEY (seller_id) REFERENCES sellers(seller_id);
GO

-- order_payments.order_id -> orders
ALTER TABLE order_payments
      ADD CONSTRAINT FK_payments_orders
      FOREIGN KEY (order_id) REFERENCES olist_orders_dataset(order_id);
GO

-- order_reviews.order_id -> orders
ALTER TABLE order_reviews
      ADD CONSTRAINT FK_reviews_orders
      FOREIGN KEY (order_id) REFERENCES olist_orders_dataset(order_id);
GO


--5. Verification
-- List all primary keys
SELECT t.name AS table_name, k.name AS pk_name
FROM   sys.key_constraints k
JOIN   sys.tables t ON k.parent_object_id = t.object_id
WHERE  k.type = 'PK'
ORDER  BY t.name;

-- List all foreign keys (expect 6)
SELECT name FROM sys.foreign_keys ORDER BY name;
GO