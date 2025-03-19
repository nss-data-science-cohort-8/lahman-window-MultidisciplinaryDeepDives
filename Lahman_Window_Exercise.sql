-- EDA:

SELECT *
FROM allstarfull;


SELECT *
FROM appearances
ORDER BY yearid DESC;


SELECT *
FROM awardsmanagers ;


SELECT *
FROM awardssharemanagers ;


SELECT *
FROM awardsshareplayers ;


SELECT *
FROM batting ;


SELECT *
FROM collegeplaying  ;


SELECT *
FROM fielding ;


SELECT *
FROM fieldingofsplit ;



SELECT *
FROM fieldingpost ;



SELECT *
FROM halloffame ;



SELECT *
FROM homegames ;



SELECT *
FROM managers ;



SELECT *
FROM managershalf ;



SELECT *
FROM parks  ;



SELECT *
FROM people ;



SELECT *
FROM pitching ;



SELECT *
FROM pitchingpost ;



SELECT *
FROM salaries  ;



SELECT *
FROM schools ;



SELECT *
FROM seriespost ;



SELECT *
FROM teams 
WHERE yearid >= 1970 AND yearid <= 2016 AND (WSWin IS NULL OR W IS NULL)
ORDER BY w DESC
;




-- Q1: Rankings
-- Q1a ~ Warmup Q: Write a query which retrieves each teamid and number of wins (w) for the 2016 season. Apply three window functions to the number of wins (ordered in descending order) - ROW_NUMBER, RANK, AND DENSE_RANK. Compare the output from these three functions. What do you notice?


SELECT
	teamid,
	w,
	RANK() OVER(ORDER BY w DESC) AS desc_rank,
	ROW_NUMBER() OVER(ORDER BY w DESC) AS rows_number,
	DENSE_RANK() OVER(ORDER BY w DESC) AS dense_ranks
FROM teams
WHERE yearid = '2016'
;




-- Q1b: Which team has finished in last place in its division (i.e. with the least number of wins) the most number of times? A team's division is indicated by the divid column in the teams table. 

--Solution 1 (by Andrew Richard):

WITH slim AS (
	SELECT 
		name,
		yearid,
		lgid||divid AS division,
		w
	FROM teams
--	WHERE lgid IS NOT NULL
--		AND divid IS NOT NULL
),
LastPlace AS(
	SELECT
		name,
		yearid,
		division,
		w,
		RANK() OVER(PARTITION BY yearid, division ORDER BY w) as rank_in_division
	FROM slim
)
SELECT 
	name,
	COUNT(*) AS number_of_last_place_finishes
FROM LastPlace
WHERE rank_in_division = 1
GROUP BY  name
ORDER BY number_of_last_place_finishes DESC
;



--Solution 2 (by Nitin), the more correct solution, since earlier years had "[default]" divisions :


WITH Data1 AS (
SELECT DISTINCT 
	yearid, 
	lgid,
	divid, 
	lgid||divid AS division, 
	teamid, 
	name, 
	w, 
	min(w) OVER(PARTITION BY yearid, lgid, divid) AS min_wins_in_division
FROM teams 
WHERE teamid IN 
	(SELECT DISTINCT teamid FROM teams)
ORDER BY yearid ASC, divid, name desc
),
Data2 AS (
SELECT DISTINCT 
	yearid, 
	divid, 
	teamid, 
	name, 
	w, 
	min_wins_in_division
FROM Data1
WHERE w = min_wins_in_division
)
SELECT 
	teamid, 
	name, 
	count(*) AS times_in_bottom_place
FROM Data2
GROUP BY teamid, name
ORDER BY times_in_bottom_place DESC
; 


--maybe ask Michael: why Solution 1 & 2 yield different #s




-- Q2: Cumulative Sums
-- Q2a: Barry Bonds has the record for the highest career home runs, with 762. Write a query which returns, for each season of Bonds' career the total number of seasons he had played and his total career home runs at the end of that season. (Barry Bonds' playerid is bondsba01.)

SELECT
	yearid,
	DENSE_RANK() OVER(ORDER BY yearid) AS season_rank,
	SUM(hr) OVER(ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS hr_rolling_total
FROM batting
WHERE playerid = 'bondsba01';





-- Q2b: How many players at the end of the 2016 season were on pace to beat Barry Bonds' record? For this question, we will consider a player to be on pace to beat Bonds' record if they have more home runs than Barry Bonds had the same number of seasons into his career.


--Solution 1, from Zach Hubbell:

WITH barry_bonds_hr AS (
	SELECT
		yearid,
		DENSE_RANK() OVER(ORDER BY yearid) AS season_rank,
		SUM(hr) OVER(ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS barry_hr_rolling_total
FROM batting
WHERE playerid = 'bondsba01'
),
player_hr AS (
	SELECT
	 	playerid,
		yearid,
		DENSE_RANK() OVER(PARTITION BY playerid ORDER BY yearid) AS season_rank,
		SUM(hr) OVER(PARTITION BY playerid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rolling_total_hr
	FROM batting
	WHERE yearid <= 2016
)
SELECT
	ph.playerid
FROM player_hr AS ph
JOIN barry_bonds_hr AS bbh
	ON ph.season_rank = bbh.season_rank 
	AND ph.yearid = 2016 
	AND ph.rolling_total_hr > bbh.barry_hr_rolling_total
;

--Side Note: using the ON clause as part of the filtering process; otherwise would have to use WHERE statement afterward





--Solution 2, from Nitin Pawar:


WITH CTE1 AS (
SELECT 
	COUNT(*) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Barry_total_seasons,
	SUM(hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Barry_tot_home_runs
FROM batting WHERE playerid = 'bondsba01'
),
CTE2 AS (
SELECT 
	playerid, 
	yearid, 
	teamid, 
	lgid, 
	hr, 
	COUNT(*) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS total_seasons,
	SUM(hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS tot_home_runs
FROM batting AS b1
WHERE EXISTS
	(SELECT 'x'
	FROM batting AS b2
	WHERE b1.playerid = b2. playerid 
		AND b2.yearid = 2016)
ORDER BY 1, 2 ASC		
)
SELECT DISTINCT 
	people.nameFirst,
	people.nameLast,
	CTE2.*,
	CTE1.*
FROM CTE2 
CROSS JOIN CTE1
INNER JOIN people
	USING (playerid)
WHERE CTE2.total_seasons = barry_total_seasons
	AND tot_home_runs >= Barry_tot_home_runs
	AND CTE2.yearid = 2016
;






-- Q2c: Were there any players who 20 years into their career who had hit more home runs at that point into their career than Barry Bonds had hit 20 years into his career?

-- Ans from Andrew Richard:


WITH hr_partition AS (
	SELECT
		namefirst ||' '|| namelast AS playername,
		playerid,
		yearid,
		SUM(hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_hr,
		RANK() OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_seasons
		--Alternative approach: COUNT(*) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_seasons	
	FROM batting AS b
	INNER JOIN people AS p 
		USING (playerid)
),
bonds AS (
	SELECT 
		cumulative_seasons,
		cumulative_hr AS bonds_hr
	FROM hr_partition
	WHERE playerid = 'bondsba01'
),
players_pace AS (
	SELECT 
		h.playername AS playername,
		h.yearid,
		h.cumulative_hr AS cumulative_hr,
		h.cumulative_seasons AS cumulative_seasons,
		b.bonds_hr,
		CASE WHEN h.cumulative_hr > b.bonds_hr THEN 'Outperformed' ELSE 'Has not outperformed' END AS pace
	FROM hr_partition AS h
	LEFT JOIN bonds AS b 
		ON h.cumulative_seasons = b.cumulative_seasons
	WHERE h.playerid != 'bondsba01'
)
SELECT playername, cumulative_hr, cumulative_seasons
FROM players_pace
WHERE pace = 'Outperformed'
	AND cumulative_seasons = 20
;






-- Q3: Anomalous Seasons: Find the player who had the most anomalous season in terms of number of home runs hit. To do this, find the player who has the largest gap between the number of home runs hit in a season and the 5-year moving average number of home runs if we consider the 5-year window centered at that year (the window should include that year, the two years prior and the two years after).

--Solution 1, by Thomas:

WITH rolling_avg AS (
	SELECT
		playerid,
		yearid,
		hr,
		ROUND(AVG (hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING), 2) avg_hr_5year
	FROM batting		
)
SELECT ra.*, abs(hr - ra.avg_hr_5year) AS largest_difference_abs_val
FROM rolling_avg AS ra
ORDER BY largest_difference_abs_val DESC
;


--Solution 2, by Nitin:

WITH CTE1 AS (
	SELECT 
		playerid, 
		yearid, 
		teamid, 
		lgid, 
		hr, 
		round(avg(hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING), 2) AS avg_5_yrs_home_run
	FROM batting	
	ORDER BY 2
),
CTE2 AS (
	SELECT 
		playerid, 
		yearid, 
		teamid, 
		lgid, 
		hr, 
		avg_5_yrs_home_run, 
		abs(hr - avg_5_yrs_home_run) AS abs_home_run_gap
		FROM CTE1
	ORDER BY yearid, playerid
)
SELECT 
	p.playerid, 
	p.nameFirst, 
	p.nameLast, 
	MAX(C1.max_hr_gap) AS max_hr_gap
FROM(
	SELECT 
		CTE2.*, 
		MAX(abs_home_run_gap) OVER(PARTITION BY playerid) AS max_hr_gap 
	FROM CTE2
				) AS C1
INNER JOIN people AS p
	ON C1.playerid = p.playerid
GROUP BY p.playerid, p.nameFirst, p.nameLast
ORDER BY max_hr_gap DESC
;
 

 



-- Q4: Players Playing for one Team: For this question, we'll just consider players that appear in the batting table.
-- Q4a: Warmup: How many players played at least 10 years in the league and played for exactly one team? (For this question, exclude any players who played in the 2016 season). Who had the longest career with a single team? (You can probably answer this question without needing to use a window function.)

-- Solution 1, by Andrew Richard; has duplicates:

WITH career AS (
	SELECT
		playerid, 
		COUNT(DISTINCT yearid) AS career_length,
		COUNT(DISTINCT teamid) AS n_teams,
		teamid
	FROM batting
	WHERE yearid <> 2016
	GROUP BY playerid, teamid
)
SELECT DISTINCT 
	nameFirst||' '||nameLast AS playername,
	career_length,
	n_teams,
	name AS team
FROM CAREER AS c
	INNER JOIN people AS p 
		USING (playerid)
	INNER JOIN teams AS t
		USING (teamid)
	WHERE career_length >= 10
		AND n_teams = 1
	ORDER BY career_length DESC
;


-- Solution 2, by Nitin:

SELECT DISTINCT 
	b1.playerid,
	COUNT(DISTINCT yearid) 
FROM batting AS b1
WHERE NOT EXISTS (
	SELECT 'x'
	FROM batting AS b2 
	WHERE b1.playerid = b2.playerid
		AND b2.yearid = 2016
)
GROUP BY b1.playerid
HAVING COUNT(DISTINCT yearid) >= 10
	AND COUNT(DISTINCT teamid) = 1
ORDER BY COUNT(DISTINCT yearid) DESC 
;






-- Q4b: Some players start and end their careers with the same team but play for other teams in between. For example, Barry Zito started his career with the Oakland Athletics, moved to the San Francisco Giants for 7 seasons before returning to the Oakland Athletics for his final season. How many players played at least 10 years in the league and start and end their careers with the same team but played for at least one other team during their career? For this question, exclude any players who played in the 2016 season.

-- Solution from Andrew Richard:

WITH career_10_multiteam AS (
	SELECT
		playerid,
		COUNT(DISTINCT yearid) AS career_length,
		COUNT(DISTINCT teamid) AS n_teams
	FROM batting
	INNER JOIN people 
		USING (playerid)
	GROUP BY playerid
	HAVING COUNT(DISTINCT yearid) >= 10
		AND COUNT(DISTINCT teamid) > 1
		AND MAX(yearid) < 2016
),
first_last_teams AS (
	SELECT DISTINCT
		playerid,
		FIRST_VALUE(teamid) OVER (PARTITION BY playerid ORDER BY yearid, stint) AS first_team,
		FIRST_VALUE(teamid) OVER (PARTITION BY playerid ORDER BY yearid DESC, stint DESC) AS last_team
	FROM batting
	WHERE yearid != 2016
)
SELECT DISTINCT
	namefirst ||' '|| namelast AS playername,
	career_length,
	n_teams AS n_distinct_teams,
	first_team,
	last_team
FROM career_10_multiteam AS cm
	INNER JOIN people p 
		USING (playerid)
	INNER JOIN first_last_teams AS flt 
		USING (playerid)
WHERE career_length >= 10 
	AND n_teams > 1
	AND first_team = last_team
ORDER BY career_length DESC
;





-- Q5: Streaks
-- Q5a: How many times did a team win the World Series in consecutive years?

 
WITH prev_win_counts AS (
	SELECT 
		yearid,
		teamid,
		CASE WHEN wswin = 'Y' THEN 1
			ELSE 0
			END AS wswin_number
	FROM teams
	WHERE wswin IN ('Y', 'N')
),
streak_finder AS (
	SELECT pwc.*,
		CASE WHEN wswin_number = 1 AND LAG(wswin_number) OVER(PARTITION BY teamid ORDER BY yearid) = 1 THEN 1
			ELSE 0
			END AS streak_finder
	FROM prev_win_counts AS pwc
),
non_dupe_streak_finder AS (
	SELECT sf.*,
		CASE WHEN streak_finder = 1 AND LEAD(streak_finder) OVER(PARTITION BY teamid ORDER BY yearid) = 0 THEN 1 
			ELSE 0
			END AS non_dupe_streak_finder
	FROM streak_finder AS sf
)
SELECT 
	* 
 -- SUM(non_dupe_streak_finder), 
 -- SUM(streak_finder)
FROM non_dupe_streak_finder
--WHERE teamid = 'NYA'  
;
		 
--Side Note: LEAD func allows one to look at the next row. LAG looks backward by 1 row.
--Since the World Series didn't start until 1903, one of the streaks isn't a World Series streak, since it happened before 1903.


-- Q5b: What is the longest steak of a team winning the World Series? Write a query that produces this result rather than scanning the output of your previous answer.

-- Q5c: A team made the playoffs in a year if either divwin, wcwin, or lgwin will are equal to 'Y'. Which team has the longest streak of making the playoffs?

-- Q5d: The 1994 season was shortened due to a strike. If we don't count a streak as being broken by this season, does this change your answer for the previous part?


-- Q6: Manager Effectiveness: Which manager had the most positive effect on a team's winning percentage? To determine this, calculate the average winning percentage in the three years before the manager's first full season and compare it to the average winning percentage for that manager's 2nd through 4th full season. Consider only managers who managed at least 4 full years at the new team and teams that had been in existence for at least 3 years prior to the manager's first full season. 