
/* 1) конверсию этой функции (кол-во добавлений в закладки по отношению к количеству просмотров страницы товара)*/


with add_bkmkrs as (
-- определить минимальную дату появления записей по типу событий "доб.товара в закладки".
-- условно обозначаю данную дату датой релиза функции. 2019-11-01
select count(id) as cnt_action 
  , id_page_view
FROM product_page_action
WHERE type = 2
group by id_page_view
),
page_view as (
select id
  , dt  as date_view -- дата просмотра страницы
  , id_product
  , id_user_account
from product_page_view
where dt >= '01.11.2019' --dt_bkmrs
),
CR AS (
select cast(count(id) as decimal) as cnt_page_view -- к-свто просмотров страницы
	, id_product
	, cast(sum(CASE WHEN id_page_view IS NOT NULL 
    		THEN cnt_action
            ELSE 0
     END) as decimal) AS sum_action_bkmrks  -- кол. целевых действий - "доб.в закладки"
  , CONVERT(VARCHAR(10), date_view, 120) AS date_dd

from page_view
	LEFT JOIN add_bkmkrs ON page_view.id = add_bkmkrs.id_page_view
group by id_product
 , CONVERT(VARCHAR(10), date_view, 120)
)
SELECT id_product
	, (sum_action_bkmrks / cnt_page_view) * 100 as CR
   	, date_dd
FROM CR
-- where (sum_action_bkmrks/cnt_page_view) * 100 > 100
-- условие where закомментировано пока, там провожу проверку есть ли записи с конверсией больше 100%
  -- 377 записей, где больше 100% конверсия.
-- проверила, что в источнике есть на одну страницу просмотра больше одного добавления в закладки. 
-- из-за этого получили выброс в данных. по хорошему такое нужно удалять с расчёта.
-- Если поррассуждать, то проблема может быть в коннекторе или API, которое забирает данные с GA, -- ------ особенно если это MS SQL с плагином Targit.
;


/*2) ту же самую конверсию, но только для тех показов страницы товара, когда пользователь зарегистрирован и у нас есть информация о том, что он/а уже ранее совершил хотя бы одну покупку.*/


with add_bkmkrs as (
select count(id) as cnt_action 
  , id_page_view
FROM product_page_action
WHERE type = 2
group by id_page_view
),
page_view as (
select v.id  -- идент.просмотра
  , v.dt  as date_view -- дата просмотра страницы
  , v.id_product
  , v.id_user_account
from product_page_view v
  -- внутр. соединение с табл. транзакций для отсечки пользователей без покупок.
  -- Если зарегистрированный польз. что-то покупал, он обязательно будет в этой таблице
  JOIN [transaction] tr ON v.id_user_account = v.id_user_account

-- неоднозначно можно интерпретировать. Совершил покупку ранее относительно чего, 
  -- даты релиза фичи? 
-- Для себя определила, что покупка была ранее, чем просмотр страницы конкретным пользователем. Без 
-- привязки к покупке конкретного товара

where tr.dt < v.dt
  --- 238 891 564
),
CR AS (
select cast(count(id) as decimal) as cnt_page_view 
	, id_product
	, cast(sum(CASE WHEN id_page_view IS NOT NULL 
    		THEN cnt_action
            ELSE 0
     END) as decimal) AS sum_action_bkmrks
  , CONVERT(VARCHAR(10), date_view, 120) AS date_dd
from page_view
	-- левое по причине того, что в зарегистр.пользователя возможно нету конверсии в закладку 
	LEFT JOIN add_bkmkrs ON page_view.id = add_bkmkrs.id_page_view
group by id_product
 , CONVERT(VARCHAR(10), date_view, 120)
)
SELECT id_product
	, round((sum_action_bkmrks / cnt_page_view) * 100, 2) as CR
   , date_dd
FROM CR
;


