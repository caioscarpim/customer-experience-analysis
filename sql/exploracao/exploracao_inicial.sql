-- ==========================================
-- EXPLORAÇÃO INICIAL - PROJETO OLIST
-- ==========================================

-- ==========================================
-- 1. PERFIL DE CLIENTES
-- ==========================================

SELECT 
	customer_state,
	COUNT(customer_id) as total_clientes
FROM customers
GROUP BY customer_state
ORDER BY total_clientes DESC;

-- Observação:
-- Maior concentração em SP, RJ e MG


SELECT 
	COUNT(DISTINCT customer_id) as clientes,
	COUNT(DISTINCT customer_unique_id) as clientes_unicos
FROM customers;

-- Observação inicial (ajustada depois):
-- Interpretação sobre recompra precisava de cuidado



-- ==========================================
-- 2. PRODUTOS
-- ==========================================

SELECT 
	COUNT(DISTINCT product_category_name) as total_categorias
FROM products;


SELECT
	P.product_category_name,
	COUNT(DISTINCT O.order_id) AS pedidos
FROM order_items O
INNER JOIN products P 
	ON P.product_id = O.product_id
GROUP BY P.product_category_name
ORDER BY pedidos DESC;



-- ==========================================
-- 3. PAGAMENTOS
-- ==========================================

SELECT
	payment_type,
	COUNT(DISTINCT order_id) as qtd_pedidos
FROM order_payments
GROUP BY payment_type
ORDER BY qtd_pedidos DESC;


-- Comparação com tabela orders

SELECT
	P.payment_type,
	COUNT(DISTINCT O.order_id) as pedidos
FROM order_payments P
INNER JOIN orders O
	ON O.order_id = P.order_id
GROUP BY P.payment_type
ORDER BY pedidos DESC;

-- Observação:
-- Cartão de crédito é o mais utilizado



-- ==========================================
-- 4. REVIEWS
-- ==========================================

SELECT
	review_score,
	COUNT(review_id) as total_reviews
FROM order_reviews
GROUP BY review_score
ORDER BY total_reviews DESC;

-- Observação:
-- Nota 1 aparece entre as mais frequentes


SELECT
	order_id,
	review_comment_title,
	review_comment_message
FROM order_reviews
WHERE review_score = 1;

-- Observação:
-- Reclamações sobre atraso, produto ruim e entrega incompleta



-- ==========================================
-- 5. SELLERS (EXPLORAÇÃO INICIAL)
-- ==========================================

SELECT
	DISTINCT I.seller_id
FROM order_reviews R
INNER JOIN order_items I
	ON I.order_id = R.order_id
WHERE R.review_score = 1;

-- Observação:
-- Muitos sellers com avaliação negativa


SELECT
	O.seller_id,
	COUNT(R.review_id) AS qtd_reviews_1
FROM order_reviews R
INNER JOIN order_items O
	ON O.order_id = R.order_id
WHERE R.review_score = 1
GROUP BY O.seller_id
ORDER BY qtd_reviews_1 DESC;



-- ==========================================
-- 6. ENTREGA (EXPLORAÇÃO INICIAL)
-- ==========================================

SELECT
	CASE 
		WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'atrasado'
		ELSE 'no_prazo'
	END AS status_entrega,
	COUNT(DISTINCT order_id) qtd_pedidos
FROM orders
WHERE order_status = 'delivered'
GROUP BY CASE 
			WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'atrasado'
			ELSE 'no_prazo'
		 END;

-- Observação:
-- Existe volume relevante de pedidos atrasados



-- ==========================================
-- 7. CATEGORIAS X ATRASO (EXPLORAÇÃO)
-- ==========================================

SELECT 
	P.product_category_name,
	COUNT(O.order_id) qtd_pedidos_atrasados
FROM orders O
LEFT JOIN order_items OI
	ON OI.order_id = O.order_id
INNER JOIN products P
	ON OI.product_id = P.product_id
WHERE O.order_delivered_customer_date > O.order_estimated_delivery_date
AND O.order_status = 'delivered'
GROUP BY P.product_category_name
ORDER BY qtd_pedidos_atrasados DESC;

-- Observação inicial:
-- Algumas categorias aparecem mais, mas ainda sem considerar proporção