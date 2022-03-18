# SQL_project_1_engeto
SQL Project (MariaDB) - Availability of Basic Foodstuffs Based on the Average Wages between 2006 - 2018 in Czech Republic.

Výzkumné otázky:

1) Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
2) Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?
3) Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?
4) Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?
5) Má výška vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?

Odpovědi:

1) V některých odvětvích mzdy vícekrát klesaly - například v oblasti těžby mzdy klesly v období 2008 - 2015 meziročně 4x. Většinu meziročních poklesů ve mzdách lze sledovat v letech 2008 - 2012 - finanční krize.
2) V roce 2006 bylo možné z průměrné mzdy koupit 1262 kg chleba, zatímco v roce 2018 1320 kg. V roce 2006 bylo možné z průměrné mzdy koupit 1409 litrů mléka, zatímco v roce 2018 1614 litrů.
3) Nejméně v průběhu sledovaného období meziročně zdražuje cukr. Ten naopak v dlouhodobém horizontu spíše zlevňuje.
4) Ve sledovaném období se nestalo, že by byl nárust cen potravin meziročně o 10 % větší než nárůst mezd. Nejblíže tomu byl meziroční nárůst cen z období 2012 / 2013, kdy došlo k poklesu průměrných mezd, ale ceny potravin se zvýšily o více jak 5 %. K absolutně nejvyššímu meziročnímu nárůstu ceny potravin došlo v období 2016 / 2017 - 9,63 % (zvýšily se ovšem mzdy o 6,4 %)
5) Není to jednoznačné. Pokud HDP roste výrazněji (např. meziročně o více než 3 %), většinou lze sledovat i výraznější nárůst mezd. Co je nicméně zajímavé, ve sledovaném období došlo k nárůstu mezd vždy, a to i při stagnaci nebo snížení HDP. Ceny potravin sice většinou meziročně stoupají, ale korelace cen potravin a HDP zcela jistě není tak vysoká jako korelace mezd a HDP. Lze to vidět například v letech, kdy došlo k meziroční stagnaci nebo poklesu HDP - ceny potravin jednou klesají, jindy nicméně stoupají, a to i velmi výrazně. To ukazuje, že do cen potravin z velké míry vstupují externí faktory - např. úroda v daném roce.

Vycházím z dat na Portálu otevřených dat ČR. Nejprve jsem si vytvořil primární tabulku sloužící jako datový podklad pro testování výzkumných otázek, využívám přitom virtuálních pomocných tabulek cen potravin a mezd v daném odvětví (pomocí klauzule WITH). Primární tabulka vznikla na základě propojení několika výchozích tabulek. Následně jsou testovány výše uvedené výzkumné otázky. Na konci SQL scriptu je vytvořena sekundární tabulka, která obsahuje relevantní data k dalším evropským státům ve stejném sledovaném období (2006 - 2018).
