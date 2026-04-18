
-- PROJETO: ANÁLISE DE EXPERIÊNCIA DO CLIENTE - OLIST
-- ==========================================
-- Objetivo: Identificar os principais fatores que impactam a satisfação do cliente
-- ==========================================


-- ==========================================
-- 1. DATA CLEANING
-- ==========================================

-- Correção de valores monetários (dados importados sem separador decimal)

ALTER TABLE order_items
ADD price_corrigido DECIMAL(10,2);

UPDATE order_items
SET price_corrigido = price / 100.0;

ALTER TABLE order_items
ADD freight_value_corrigido DECIMAL(10,2);

UPDATE order_items
SET freight_value_corrigido = freight_value / 100.0;

ALTER TABLE order_payments
ADD payment_value_clean DECIMAL(10,2);

UPDATE order_payments
SET payment_value_clean = payment_value / 100.0;



-- ==========================================
-- 2. IDENTIFICAÇÃO DO PROBLEMA
-- ==========================================

-- Distribuição das avaliações

SELECT
	review_score,
	COUNT(review_id) as total_reviews
FROM order_reviews
GROUP BY review_score
ORDER BY total_reviews desc;

-- Observação:
-- Avaliações com nota 1 aparecem entre as mais frequentes,
-- levantando a necessidade de investigar os fatores de insatisfação.



-- ==========================================
-- 3. ANÁLISE QUALITATIVA (COMENTÁRIOS)
-- ==========================================

SELECT
	order_id,
	review_comment_title,
	review_comment_message
FROM order_reviews
WHERE review_score = 1;

-- Observação:
-- Reclamações frequentes: atraso na entrega, problemas com produto, pedidos incompletos.



-- ==========================================
-- 4. HIPÓTESE 1: SELLERS
-- ==========================================

-- Quantos sellers já receberam avaliações negativas?

SELECT
	COUNT(DISTINCT OI.seller_id) as sellers_com_review_ruim
FROM order_reviews R
INNER JOIN order_items OI
	ON OI.order_id = R.order_id
WHERE R.review_score = 1;

-- Análise da taxa de insatisfação por seller (considerando volume)

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
HAVING COUNT(*) >= 50
ORDER BY pct_review_1 DESC;

-- Insight:
-- A maioria dos sellers apresenta taxas de insatisfação relativamente próximas,
-- indicando que o problema não está concentrado em poucos vendedores

-- Observação:
-- Em muitos casos, a taxa de avaliações negativas é superior à taxa de atraso,
-- sugerindo que a insatisfação do cliente não é explicada apenas por questões logísticas

-- Conclusão:
-- A experiência negativa do cliente é influenciada por múltiplos fatores,
-- e não exclusivamente pelo desempenho dos sellers ou atrasos na entrega
 


-- ==========================================
-- 5. INVESTIGAÇÃO: ENTREGA VS SATISFAÇÃO
-- ==========================================

-- Quantidade de pedidos atrasados vs no prazo

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

-- Relação entre atraso e avaliação

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

-- Insight principal: 
-- Pedidos atrasados possuem uma taxa de insatisfação significativamente maior (~46%)
-- comparado aos pedidos entregues no prazo (~6.6%).
-- Pedidos atrasados apresentam uma taxa de insatisfação ~7x maior
-- do que pedidos entregues no prazo



-- ==========================================
-- 6. INVESTIGAÇÃO: CATEGORIAS DE PRODUTO
-- ==========================================

SELECT
	P.product_category_name,
	COUNT(DISTINCT CASE 
		WHEN O.order_delivered_customer_date > O.order_estimated_delivery_date 
		THEN O.order_id 
	END) AS pedidos_atrasados,
	COUNT(DISTINCT O.order_id) AS total_pedidos,
	(COUNT(DISTINCT CASE 
		WHEN O.order_delivered_customer_date > O.order_estimated_delivery_date 
		THEN O.order_id 
	END) * 100.0) / NULLIF(COUNT(DISTINCT O.order_id), 0) AS pct_atraso
FROM orders O
INNER JOIN order_items OI
	ON OI.order_id = O.order_id
INNER JOIN products P
	ON P.product_id = OI.product_id
WHERE O.order_status = 'delivered'  
GROUP BY P.product_category_name
HAVING COUNT(DISTINCT O.order_id) >= 200 -- evitar distorções por baixo volume
ORDER BY pct_atraso DESC;

-- Conclusão: 
-- As taxas de atraso são semelhantes entre categorias,
-- indicando que o problema não está ligado a produtos específicos



-- ==========================================
-- 7. ANÁLISE REGIONAL
-- ==========================================

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
HAVING COUNT(DISTINCT O.order_id) > 200 -- foco em volume relevante
ORDER BY pct_atraso DESC;

-- Conclusão:
-- Existem diferenças regionais relevantes nas taxas de atraso,
-- indicando possíveis gargalos logísticos localizados
