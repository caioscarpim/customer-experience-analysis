-- ==========================================
-- VIEWS
-- ==========================================


-- DISTRIBUIÇÃO DAS AVALIAÇÕES

CREATE VIEW vw_distribuicao_reviews AS 
SELECT
	review_score,
	COUNT(review_id) as total_reviews
FROM order_reviews
GROUP BY review_score;


-- PERFORMANCE DOS SELLERS

CREATE VIEW vw_performance_sellers AS
WITH base AS (
	SELECT
		OI.seller_id,
		O.order_id,
		MAX(CASE 
			WHEN O.order_delivered_customer_date > O.order_estimated_delivery_date 
			THEN 1 ELSE 0 
		END) AS flag_atraso,
		MAX(CASE 
			WHEN R.review_score = 1 THEN 1 ELSE 0 
		END) AS flag_review_1
	FROM orders O
	INNER JOIN order_items OI
		ON OI.order_id = O.order_id
	INNER JOIN order_reviews R
		ON R.order_id = O.order_id
	WHERE O.order_status = 'delivered'
	GROUP BY OI.seller_id, O.order_id
)

SELECT
	seller_id,
	COUNT(*) AS total_pedidos, -- 1 linha = 1 pedido por seller
	AVG(flag_atraso * 100.0) AS pct_atraso,
	AVG(flag_review_1 * 100.0) AS pct_review_1
FROM base
GROUP BY seller_id
HAVING COUNT(*) >= 50;


-- ATRASO VS NO PRAZO

CREATE VIEW vw_status_entrega AS
SELECT
	CASE 
		WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'atrasado'
		ELSE 'no_prazo'
	END AS status_entrega,
	COUNT(DISTINCT order_id) total_pedidos
FROM orders
WHERE order_status = 'delivered'
GROUP BY CASE 
			WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'atrasado'
			ELSE 'no_prazo'
		 END;


-- IMPACTO DOS ATRASOS NA SATISFAÇÃO DOS CLIENTES

CREATE VIEW vw_impacto_atraso_satisfacao AS
WITH base AS (
	SELECT
		CASE 
			WHEN O.order_delivered_customer_date > O.order_estimated_delivery_date THEN 'atrasado'
			ELSE 'no_prazo'
		END AS status_entrega,
		R.review_score
	FROM orders O
	INNER JOIN order_reviews R
		ON R.order_id = O.order_id
	WHERE O.order_status = 'delivered'
)

SELECT
	status_entrega,
	COUNT(*) AS total_pedidos,
	COUNT(CASE WHEN review_score = 1 THEN 1 END) AS total_review_1,
	(COUNT(CASE WHEN review_score = 1 THEN 1 END) * 100.0) / COUNT(*) AS pct_review_1
FROM base
GROUP BY status_entrega;


-- ATRASOS POR ESTADOS

CREATE VIEW vw_atraso_por_estado AS
SELECT
	C.customer_state,
	COUNT(DISTINCT CASE 
		WHEN O.order_delivered_customer_date > O.order_estimated_delivery_date 
		THEN O.order_id 
	END) AS pedidos_atrasados,
	COUNT(DISTINCT O.order_id) total_pedidos,
	(COUNT(DISTINCT CASE 
		WHEN O.order_delivered_customer_date > O.order_estimated_delivery_date 
		THEN O.order_id 
	END) * 100.0) / NULLIF(COUNT(DISTINCT O.order_id), 0) AS pct_atraso
FROM orders O
INNER JOIN customers C
	ON C.customer_id = O.customer_id
GROUP BY C.customer_state
HAVING COUNT(DISTINCT O.order_id) > 200;