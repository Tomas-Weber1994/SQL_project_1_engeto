/* Vytvoøení primární tabulky sloužící jako datový podklad pro testování výzkumných otázek - 
 * využívám virtuálních pomocných tabulek cen potravin a mezd v daném odvìtví */

CREATE OR REPLACE TABLE t_tomas_weber_project_SQL_primary_final AS
WITH price_table AS (
	SELECT 
		cpc.name AS food_name, 
		cpc.code, 
		cpc.price_value, 
		cpc.price_unit, 
		AVG(cp.value) AS average_food_price, 
		YEAR(cp.date_from) AS year_of_measurement
	FROM czechia_price cp
	JOIN czechia_price_category cpc 
		ON cp.category_code = cpc.code
	WHERE cp.region_code IS NULL 		/* hodnoty v jednotlivých krajích nás aktuálnì nezajímají */ 
	GROUP BY 
		food_name, cpc.price_value, cpc.code, cpc.price_unit, year_of_measurement	
	), 
wage_table AS (
	SELECT 
		AVG(cpay.value) AS average_wage_per_industry_branch, 
		cpib.code AS industry_branch_code, 
		cpib.name AS industry_branch_name, 
		cpay.payroll_year
	FROM czechia_payroll cpay
	JOIN czechia_payroll_industry_branch cpib
		ON cpay.industry_branch_code = cpib.code 
	WHERE 
		cpay.value_type_code = 5958 
		AND cpay.calculation_code = 100 
	GROUP BY 
		industry_branch_name, cpay.payroll_year, cpib.code
	) 
SELECT 
	pc.year_of_measurement, 
	e.GDP, 
	pc.code AS food_category_code, 
	pc.food_name, pc.average_food_price, 
	pc.price_value, 
	pc.price_unit, 
	wt.average_wage_per_industry_branch, 
	wt.industry_branch_code, 
	wt.industry_branch_name
FROM price_table pc
JOIN wage_table wt
	ON pc.year_of_measurement = wt.payroll_year
JOIN economies e /*Spárování s tabulkou, kde je uvedeno GDP */
	ON year_of_measurement = e.`year` 
	AND e.country = 'Czech republic'
ORDER BY pc.year_of_measurement;

--- Výzkumné otázky ---

/* 1) Rostou v prùbìhu let mzdy ve všech odvìtvích, nebo v nìkterých klesají? 
 * 
 * Odpovìï: 
 * 
 * V nìkterých odvìtvích mzdy vícekrát klesaly - napøíklad v oblasti tìžby mzdy klesly v období 2008 - 2015 meziroènì 4x.
 * Vìtšinu meziroèních poklesù ve mzdách lze sledovat v letech 2008 - 2012 - finanèní krize
 * 
 * SQL dotaz níže
 */

WITH t1 AS (
	SELECT DISTINCT 
		year_of_measurement, 
		average_wage_per_industry_branch, 
		industry_branch_code, 
		industry_branch_name 
	FROM t_tomas_weber_project_SQL_primary_final
	), 
t2 AS (
	SELECT DISTINCT 
		year_of_measurement, 
		average_wage_per_industry_branch, 
		industry_branch_code, 
		industry_branch_name 
	FROM t_tomas_weber_project_SQL_primary_final
	)
SELECT 
	t1.year_of_measurement AS year1, 
	t1.industry_branch_code, 
	t1.industry_branch_name, 
	t1.average_wage_per_industry_branch AS average_salary_year1, 
	t2.year_of_measurement AS year2, 
	t2.average_wage_per_industry_branch AS average_salary_year2, 
	ROUND((t2.average_wage_per_industry_branch - t1.average_wage_per_industry_branch) / t1.average_wage_per_industry_branch*100,2) AS diff_in_percent
FROM t1
JOIN t2
	ON t1.industry_branch_code = t2.industry_branch_code
	AND t1.year_of_measurement = t2.year_of_measurement -1
WHERE t2.average_wage_per_industry_branch < t1.average_wage_per_industry_branch
ORDER BY t1.industry_branch_name, year1;

/* 2) Kolik je možné si koupit litrù mléka a kilogramù chleba 
 *	za první a poslední srovnatelné období v dostupných datech cen a mezd?
 *
 * Odpovìï: 
 *
 * V roce 2006 bylo možné z prùmìrné mzdy koupit 1262 kg chleba, zatímco v roce 2018 1320 kg.
 * V roce 2006 bylo možné z prùmìrné mzdy koupit 1409 litrù mléka, zatímco v roce 2018 1614 litrù.
 
 * SQL níže
 */ 

WITH t1 AS (
	SELECT 
		average_food_price, 
		year_of_measurement, 
		food_name,  
		AVG(average_wage_per_industry_branch) AS average_wage_2006
	FROM t_tomas_weber_project_SQL_primary_final  
	WHERE 
		food_name in ('Chléb konzumní kmínový', 'Mléko polotuèné pasterované') 
		AND year_of_measurement = 2006
	GROUP BY 
		food_name, average_food_price, year_of_measurement
	),
t2 AS (
	SELECT 
		average_food_price, 
		year_of_measurement, 
		food_name,  
		AVG(average_wage_per_industry_branch) AS average_wage_2018
	FROM t_tomas_weber_project_SQL_primary_final  
	WHERE 
		food_name in ('Chléb konzumní kmínový', 'Mléko polotuèné pasterované') 
		AND year_of_measurement = 2018
	GROUP BY 
		food_name, average_food_price, year_of_measurement
)
SELECT 
	t1.food_name, 
	t1.average_food_price AS average_food_price_2006, 
	ROUND(t1.average_wage_2006) AS average_wage_2006, 
	t2.average_food_price AS average_food_price_2018, 
	ROUND(t2.average_wage_2018) AS average_wage_2018,
	CEIL(t1.average_wage_2006 / t1.average_food_price) AS num_goods_per_wage_2006,
	CEIL(t2.average_wage_2018 / t2.average_food_price) AS num_goods_per_wage_2018
FROM t1
JOIN t2
	ON t1.food_name = t2.food_name;

/* 3) Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroèní nárùst)?
 * 
 * Odpovìï: Nejménì v prùbìhu sledovaného období meziroènì zdražuje cukr. Ten naopak v dlouhodobém horizontu spíše zlevòuje.
 * SQL níže */

--- Pomocné view, sloužící pozdìji k výpoètu prùmìrného meziroèního procentuálního nárustu cen potravin ---

CREATE OR REPLACE VIEW v_tomas_weber_price_increase AS 
WITH t1 AS (
	SELECT DISTINCT 
		food_name, 
		year_of_measurement, 
		average_food_price 
	FROM t_tomas_weber_project_SQL_primary_final 
	),
t2 AS (
	SELECT DISTINCT 
		food_name, 
		year_of_measurement, 
		average_food_price 
	FROM t_tomas_weber_project_SQL_primary_final 
)
SELECT 
	t1.food_name, 
	t1.year_of_measurement AS year_of_measurement_1, 
	ROUND(t1.average_food_price,2) AS average_food_price_1, 
	t2.year_of_measurement AS year_of_measurement_2, 
	ROUND(t2.average_food_price,2) AS average_food_price_2, 
	ROUND((t2.average_food_price - t1.average_food_price) / t1.average_food_price * 100,2) AS diff_in_percent
FROM t1
JOIN t2
	ON t1.food_name = t2.food_name 
	AND t1.year_of_measurement = t2.year_of_measurement - 1
ORDER BY (t2.average_food_price - t1.average_food_price) / t1.average_food_price * 100;

SELECT 
	food_name, 
	ROUND(AVG(diff_in_percent),2) AS average_price_increase_in_percent
FROM v_tomas_weber_price_increase 
GROUP BY food_name
ORDER BY AVG(diff_in_percent);

/* 4) Existuje rok, ve kterém byl meziroèní nárùst cen potravin výraznì vyšší než rùst mezd (vìtší než 10 %)?
 * 
 * Odpovìï: 
 * 
 * Ve sledovaném období se nestalo, že by byl nárust cen potravin meziroènì o 10 % vìtší než nárùst mezd.
 * Nejblíže tomu byl meziroèní nárùst cen z období 2012 / 2013, kdy došlo k poklesu prùmìrných mezd, 
 * ale ceny potravin se zvýšily o více jak 5 %. 
 * K absolutnì nejvyššímu meziroènímu nárùstu ceny potravin došlo v období 2016 / 2017 - 9,63 % (zvýšily se ovšem mzdy o 6,4 %)
 * 
 * SQL níže */

WITH t1 AS (
	SELECT 
		year_of_measurement AS year_of_measurement_1, 
		ROUND(AVG(average_food_price),2) AS average_food_price_1, 
		ROUND(AVG(average_wage_per_industry_branch)) AS average_wage_1
	FROM t_tomas_weber_project_SQL_primary_final  
	GROUP BY year_of_measurement
), 
t2 AS (
	SELECT 
		year_of_measurement AS year_of_measurement_2, 
		ROUND(AVG(average_food_price),2) AS average_food_price_2, 
		ROUND(AVG(average_wage_per_industry_branch)) AS average_wage_2
	FROM t_tomas_weber_project_SQL_primary_final  
	GROUP BY year_of_measurement
)
SELECT 
	*, 
	ROUND((t2.average_food_price_2  - t1.average_food_price_1) / t1.average_food_price_1 * 100, 2) AS diff_food_price_percent,
	ROUND((t2.average_wage_2  - t1.average_wage_1) / t1.average_wage_1 * 100, 2) AS diff_avg_wage_percent
FROM t1
JOIN t2 
	ON t1.year_of_measurement_1 = t2.year_of_measurement_2 - 1	
WHERE (t2.average_food_price_2  - t1.average_food_price_1) / t1.average_food_price_1 * 100 > (t2.average_wage_2  - t1.average_wage_1) / t1.average_wage_1 * 100;

/* Ve WHERE klauzuli výše vybírám øádky (roky), ve kterých došlo k vìtšímu nárustu cen potravin než platù. 
 * Alternativa - pokud chci najít rok, ve kterém potraviny zdražily o více jak 10 % (zadání pro mì není jednoznaèné), využiji:
 * WHERE (t2.average_food_price_2  - t1.average_food_price_1) / t1.average_food_price_1 * 100 > 10; == Takový pøípad nenastal
 */


/*  5) Má výška HDP vliv na zmìny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výraznìji v jednom roce, 
 * projeví se to na cenách potravin èi mzdách ve stejném nebo násdujícím roce výraznìjším rùstem? 
 *
 * Odpovìï: 
 * 
 * Není to jednoznaèné. Pokud HDP roste výraznìji (napø. meziroènì o více než 3 %), vìtšinou lze sledovat i výraznìjší nárùst mezd.
 * Co je nicménì zajímavé, ve sledovaném období došlo k nárùstu mezd vždy, a to i pøi stagnaci nebo snížení HDP. 
 * Ceny potravin sice vìtšinou meziroènì stoupají, ale korelace cen potravin a HDP zcela jistì není tak vysoká jako korelace mezd a HDP.
 * Lze to vidìt napøíklad v letech, kdy došlo k meziroèní stagnaci nebo poklesu HDP - ceny potravin jednou klesají, jindy nicménì stoupají, a to i velmi výraznì.
 * To ukazuje, že do cen potravin z velké míry vstupují externí faktory - napø. úroda v daném roce
 * 
 * SQL níže */

--- vytvoøení pomocného VIEW pro následný výpoèet meziroèních rocentuálních rozdílù v platech, GDP a cenách potravin ---

CREATE OR REPLACE VIEW v_tomas_weber_GDP_salary_price_comparison AS 
	WITH t1 AS (
		SELECT 
			year_of_measurement,
			ROUND(AVG(average_wage_per_industry_branch)) AS average_wage,
			ROUND(AVG(average_food_price),2) AS average_food_price,
			GDP
		FROM t_tomas_weber_project_SQL_primary_final  
		GROUP BY year_of_measurement
	)
	SELECT *, 
		LAG(GDP)  
	        OVER (ORDER BY average_wage) AS GDP_year_before,
		LAG(average_wage)  
	        OVER (ORDER BY average_wage) AS average_wage_year_before,
		LAG(average_food_price)  
			OVER (ORDER BY average_wage) AS average_food_price_year_before
	FROM t1;

SELECT 
	year_of_measurement AS 'year',
	ROUND((GDP - GDP_year_before) / GDP*100,2) AS GDP_percentual_diff,
	ROUND((average_wage - average_wage_year_before) / average_wage*100,2) AS avg_wage_percentual_diff,
	ROUND((average_food_price - average_food_price_year_before) / average_food_price*100,2) AS avg_food_price_percentual_diff
FROM v_tomas_weber_GDP_salary_price_comparison 
WHERE GDP_year_before IS NOT NULL 
ORDER BY (GDP - GDP_year_before) / GDP*100 DESC;


--- Níže dodateèný materiál: tabulka s HDP, GINI koeficientem a populací dalších evropských státù ve stejném období, jako primární pøehled pro ÈR. ---

CREATE OR REPLACE TABLE t_tomas_weber_project_SQL_secondary_final AS (
	SELECT 
		year, 
		country,
		GDP, 
		GINI, 
		population
	FROM economies e
	WHERE 
		`year` IN (
			SELECT 
				DISTINCT year_of_measurement 
			FROM t_tomas_weber_project_SQL_primary_final) /* stejné období jako pøehled pro ÈR výše */
		AND country IN (
			SELECT 
				DISTINCT country 
			FROM countries 
			WHERE continent = 'Europe') /* Výbìr pouze státù, v tabulce economies jsou totiž i celé oblasti dohromady */
	ORDER BY `year`, GDP DESC
	);
