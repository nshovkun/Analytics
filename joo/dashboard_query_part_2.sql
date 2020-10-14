-- дарборд по ссылке: https://app.powerbi.com/groups/me/reports/08487eaf-0ace-44d8-ae11-1c64a57c0078?ctid=be2e4938-4a97-48ba-8cb5-ee9db1baee40
-- на случай если будут трудности с доступом,  так же приложила файлом - dashboard.pbix

--1. Количество добавлений в закладки по дням. Данные нужны для мониторинга, не сломалась ли функция.

select count(id) as cnt_action 
  , CONVERT(VARCHAR(10), dt, 120)  AS date_dd
FROM product_page_action
WHERE type = 2
group by CONVERT(VARCHAR(10), dt, 120) 
order by CONVERT(VARCHAR(10), dt, 120) 


/*
2. Количество конверсий из просмотра страницы в добавленную закладку по дням. Продуктового менеджера интересует, если ли сезонность у использования функции.
*/


with add_bkmkrs as (
select count(id) as cnt_action 
  , id_page_view
FROM product_page_action
WHERE type = 2
group by id_page_view
-- здесь count, потому как обнаружила что бывает больше одного действия для страницы просмотра.
-- 654 rows where action > 1, 27654 rows where action = 1
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
select id_product
  	, CONVERT(VARCHAR(10), date_view, 120) AS date_dd
from page_view
	-- внутр.соединение оставить только страницы с закладками
	 JOIN add_bkmkrs ON page_view.id = add_bkmkrs.id_page_view
)
SELECT count(id_product) as cnt_convers
   , date_dd
FROM CR
group by date_dd
-- тут провожу проверку есть ли записи с конверсией больше 100%
-- where (sum_action_bkmrks/cnt_page_view) * 100 > 100  -- 377 записей, где больше 100% конверсия.
-- проверила, что в источнике есть на одну страницу просмотра больше одного добавления в закладки. 
-- из-за этого получили выброс в данных. по хорошему такое нужно удалять с расчёта.
-- Если поррассуждать, то проблема может быть в коннекторе или API, которое забирает данные с GA, -- ------ особенно если это MS SQL с плагином Targit.
;

/*
3. Конверсия из закладок в покупку для зарегистрированных пользователей (за всю историю использования фичи). Полезна ли функция для бизнеса? Делают ли покупку после добавления? Продуктовый менеджер хотел бы также видеть эту конверсию для выбранного им продукта за выбранный отрезок времени.
*/

with add_bkmkrs as (
select count(id) as cnt_action 
  , id_page_view
  , dt as date_bkmrk
FROM product_page_action
WHERE type = 2
group by id_page_view
  , dt
),
page_view as (
select id
  , dt  as date_view -- дата просмотра страницы
  , id_product
  , id_user_account
from product_page_view
WHERE dt >= '01.11.2019' --dt_bkmrs
  and id_user_account is not null -- только зарегистрированные 
),
CR AS (
select cast(count(page_view.id) as decimal) as cnt_page_view 
	, page_view.id_product
	, cast(sum(cnt_action) as decimal) AS sum_action_bkmrks
  	, CASE WHEN t_act.id_user_account IS NOT NULL 
    		THEN 1
            ELSE 0
     END AS conv_in_buy
  	, CONVERT(VARCHAR(10), date_view, 120) AS date_dd
from page_view
	 JOIN add_bkmkrs ON page_view.id = add_bkmkrs.id_page_view
  	LEFT JOIN [transaction]	t_act ON t_act.id_user_account = page_view.id_user_account --покупка конктрет.пользователем
							AND t_act.id_product = page_view.id_product --покупка конкр.продукта
where t_act.dt >  add_bkmkrs.date_bkmrk -- дата совершения покупки при этом больше, чем добавл/просмотра в закладки
group by page_view.id_product
 , CONVERT(VARCHAR(10), date_view, 120)
 , CASE WHEN t_act.id_user_account IS NOT NULL 
    		THEN 1
            ELSE 0
     END
)
SELECT id_product
	, date_dd
    , cast(conv_in_buy as decimal) / cnt_page_view
FROM CR

/*
4. Топ 100 продуктов по добавлению в закладки. Интересует, на какие продукты есть наибольший отложенный спрос?
*/

with add_bkmkrs as (
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
select cast(count(id) as decimal) as cnt_page_view 
	, id_product
	, cast(sum(CASE WHEN id_page_view IS NOT NULL 
    		THEN cnt_action
            ELSE 0
     END) as decimal) AS sum_action_bkmrks
from page_view
	 JOIN add_bkmkrs ON page_view.id = add_bkmkrs.id_page_view
group by id_product
)
SELECT top 100 id_product
	, sum_action_bkmrks
	, ROW_NUMBER() OVER (ORDER BY sum_action_bkmrks desc) AS rank
FROM CR
;


/*
5. Топ 10 продуктов с наибольшей конверсией добавления в закладки для продуктов с количеством просмотров более 10 раз.
*/


with add_bkmkrs as (
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
select cast(count(id) as decimal) as cnt_page_view 
	, id_product
	, cast(sum(CASE WHEN id_page_view IS NOT NULL 
    		THEN cnt_action
            ELSE 0
     END) as decimal) AS sum_action_bkmrks

from page_view
	 JOIN add_bkmkrs ON page_view.id = add_bkmkrs.id_page_view
group by id_product

having cast(count(id) as decimal) > 10  -- просмотрел страницу больше 10 р.
)
-- 588 > 1 добавл.в закл.
SELECT id_product
	, ROW
FROM (SELECT TOP 10 *
	, ROW_NUMBER() OVER(ORDER BY sum_action_bkmrks desc) AS Row
FROM CR
     ) A
where ROW <=10
;

/*
6. Для топ 10 продуктов из пункта 5 продуктовый менеджера собирается сделать рассылку всем зарегистрированным пользователям, которые добавили в закладки, но ещё не купили данный продукт. Для рассылки нужна таблица с id продукта и id аккаунта.
*/

with add_bkmkrs as (

select count(id) as cnt_action 
  , id_page_view
  , dt as date_bkmrk
FROM product_page_action
WHERE type = 2
group by id_page_view
  , dt
),
page_view as (
select id
  , dt  as date_view -- дата просмотра страницы
  , id_product
  , id_user_account
from product_page_view
WHERE
/*dt >= '01.11.2019' --dt_bkmrs
  and*/ id_user_account is not null -- только зарегистрированные 
),
CR AS (
select distinct page_view.id_product
	, page_view.id_user_account
from page_view
	 JOIN add_bkmkrs ON page_view.id = add_bkmkrs.id_page_view
  	LEFT JOIN [transaction]	t_act ON t_act.id_user_account = page_view.id_user_account -- конктрет.пользователь
							AND t_act.id_product = page_view.id_product --конкр.продукт
where t_act.id_user_account IS NULL --500
)
SELECT * 
FROM CR
where id_product in 
-- на уровне запроса отсекаю через условие in - список топ-10 определен на предыдущем шаге (без условия на конкретную дату, поэтому расчёт произведен за всю историю фичи), но выгрузка у файл происходила без наложения условия in.
--  Затем уже на уровне дашборда PowerBI провожу джоин таблиц (полученной в п.5 и пулом данных без наложения на ) в PowerQuery,т.к. список топ-10 динамично изменяется
(-4084270930636705835,
7634980934793306062,
8461034660484238577,
-8711959655244740687,
2703563918893015993,
368738658726655851,
-5453255727916781635,
-1298281158676466058,
-7475839328573603501,
6767207436519718608
)
-- есть сомнения по поводу определения покупки и соотвественно по показателям конверсии. Поясню по каким причинам. Его возможно определить только 
-- по таблице транзакций или так же по типу действий из product_page_view 
-- в таком случае не дана полная расшифровка типов возможн.совершаемых действий  в таблице
 --product_page_action.
