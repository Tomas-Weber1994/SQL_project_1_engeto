/* Vytvo�en� prim�rn� tabulky slou��c� jako datov� podklad pro testov�n� v�zkumn�ch ot�zek - 
 * vyu��v�m virtu�ln�ch pomocn�ch tabulek cen potravin a mezd v dan�m odv�tv� */

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
	WHERE cp.region_code IS NULL 		/* hodnoty v jednotliv�ch kraj�ch n�s aktu�ln� nezaj�maj� */ 
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
JOIN economies e /*Sp�rov�n� s tabulkou, kde je uvedeno GDP */
	ON year_of_measurement = e.`year` 
	AND e.country = 'Czech republic'
ORDER BY pc.year_of_measurement;

--- V�zkumn� ot�zky ---

/* 1) Rostou v pr�b�hu let mzdy ve v�ech odv�tv�ch, nebo v n�kter�ch klesaj�? 
 * 
 * Odpov��: 
 * 
 * V n�kter�ch odv�tv�ch mzdy v�cekr�t klesaly - nap��klad v oblasti t�by mzdy klesly v obdob� 2008 - 2015 meziro�n� 4x.
 * V�t�inu meziro�n�ch pokles� ve mzd�ch lze sledovat v letech 2008 - 2012 - finan�n� krize
 * 
 * SQL dotaz n�e
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

/* 2) Kolik je mo�n� si koupit litr� ml�ka a kilogram� chleba 
 *	za prvn� a posledn� srovnateln� obdob� v dostupn�ch datech cen a mezd?
 *
 * Odpov��: 
 *
 * V roce 2006 bylo mo�n� z pr�m�rn� mzdy koupit 1262 kg chleba, zat�mco v roce 2018 1320 kg.
 * V roce 2006 bylo mo�n� z pr�m�rn� mzdy koupit 1409 litr� ml�ka, zat�mco v roce 2018 1614 litr�.
 
 * SQL n�e
 */ 

WITH t1 AS (
	SELECT 
		average_food_price, 
		year_of_measurement, 
		food_name,  
		AVG(average_wage_per_industry_branch) AS average_wage_2006
	FROM t_tomas_weber_project_SQL_primary_final  
	WHERE 
		food_name in ('Chl�b konzumn� km�nov�', 'Ml�ko polotu�n� pasterovan�') 
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
		food_name in ('Chl�b konzumn� km�nov�', 'Ml�ko polotu�n� pasterovan�') 
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

/* 3) Kter� kategorie potravin zdra�uje nejpomaleji (je u n� nejni��� percentu�ln� meziro�n� n�r�st)?
 * 
 * Odpov��: Nejm�n� v pr�b�hu sledovan�ho obdob� meziro�n� zdra�uje cukr. Ten naopak v dlouhodob�m horizontu sp�e zlev�uje.
 * SQL n�e */

--- Pomocn� view, slou��c� pozd�ji k v�po�tu pr�m�rn�ho meziro�n�ho procentu�ln�ho n�rustu cen potravin ---

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

/* 4) Existuje rok, ve kter�m byl meziro�n� n�r�st cen potravin v�razn� vy��� ne� r�st mezd (v�t�� ne� 10 %)?
 * 
 * Odpov��: 
 * 
 * Ve sledovan�m obdob� se nestalo, �e by byl n�rust cen potravin meziro�n� o 10 % v�t�� ne� n�r�st mezd.
 * Nejbl�e tomu byl meziro�n� n�r�st cen z obdob� 2012 / 2013, kdy do�lo k poklesu pr�m�rn�ch mezd, 
 * ale ceny potravin se zv��ily o v�ce jak 5 %. 
 * K absolutn� nejvy���mu meziro�n�mu n�r�stu ceny potravin do�lo v obdob� 2016 / 2017 - 9,63 % (zv��ily se ov�em mzdy o 6,4 %)
 * 
 * SQL n�e */

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

/* Ve WHERE klauzuli v��e vyb�r�m ��dky (roky), ve kter�ch do�lo k v�t��mu n�rustu cen potravin ne� plat�. 
 * Alternativa - pokud chci naj�t rok, ve kter�m potraviny zdra�ily o v�ce jak 10 % (zad�n� pro m� nen� jednozna�n�), vyu�iji:
 * WHERE (t2.average_food_price_2  - t1.average_food_price_1) / t1.average_food_price_1 * 100 > 10; == Takov� p��pad nenastal
 */


/*  5) M� v��ka HDP vliv na zm�ny ve mzd�ch a cen�ch potravin? Neboli, pokud HDP vzroste v�razn�ji v jednom roce, 
 * projev� se to na cen�ch potravin �i mzd�ch ve stejn�m nebo n�sduj�c�m roce v�razn�j��m r�stem? 
 *
 * Odpov��: 
 * 
 * Nen� to jednozna�n�. Pokud HDP roste v�razn�ji (nap�. meziro�n� o v�ce ne� 3 %), v�t�inou lze sledovat i v�razn�j�� n�r�st mezd.
 * Co je nicm�n� zaj�mav�, ve sledovan�m obdob� do�lo k n�r�stu mezd v�dy, a to i p�i stagnaci nebo sn�en� HDP. 
 * Ceny potravin sice v�t�inou meziro�n� stoupaj�, ale korelace cen potravin a HDP zcela jist� nen� tak vysok� jako korelace mezd a HDP.
 * Lze to vid�t nap��klad v letech, kdy do�lo k meziro�n� stagnaci nebo poklesu HDP - ceny potravin jednou klesaj�, jindy nicm�n� stoupaj�, a to i velmi v�razn�.
 * To ukazuje, �e do cen potravin z velk� m�ry vstupuj� extern� faktory - nap�. �roda v dan�m roce
 * 
 * SQL n�e */

--- vytvo�en� pomocn�ho VIEW pro n�sledn� v�po�et meziro�n�ch rocentu�ln�ch rozd�l� v platech, GDP a cen�ch potravin ---

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


--- N�e dodate�n� materi�l: tabulka s HDP, GINI koeficientem a populac� dal��ch evropsk�ch st�t� ve stejn�m obdob�, jako prim�rn� p�ehled pro �R. ---

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
			FROM t_tomas_weber_project_SQL_primary_final) /* stejn� obdob� jako p�ehled pro �R v��e */
		AND country IN (
			SELECT 
				DISTINCT country 
			FROM countries 
			WHERE continent = 'Europe') /* V�b�r pouze st�t�, v tabulce economies jsou toti� i cel� oblasti dohromady */
	ORDER BY `year`, GDP DESC
	);
