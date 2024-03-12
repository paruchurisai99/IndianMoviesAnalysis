/* I want to normalize the Indian_Movies table and I wanted to do it in SQL server 
and also do some data cleaning in the process. So, here are the list of commands I used to normalize the table */

-- To know the table structure
sp_help Indian_Movies


-- Created another table "IndianMovies" with an extra column from the original one
CREATE TABLE IndianMovies (
ID nvarchar(100),
Movie_name nvarchar(max),
Year nvarchar(100),
Timing_min nvarchar(100),
Rating_10 nvarchar(10),
Votes nvarchar(100),
Genre nvarchar(max),
Language nvarchar(100),
Genre_list nvarchar(max));


/* Used the string_split function so that we can divide the genre column multiple values
into different rows and placed the result into genre_list column */
INSERT INTO IndianMovies
SELECT * FROM Indian_movies CROSS APPLY string_split(Genre,',');


-- Altered the table to remove the original "Genre" column as we now have the Genre_list column
ALTER TABLE IndianMovies
DROP COLUMN Genre;


/* Created a new table Genre so that now the IndianMovies table is in 1NF
and also we used the IDENTITY(1,1) so that it the ID col will auto increment for every record inserted*/
CREATE TABLE Genre (
Genre_ID INT PRIMARY KEY IDENTITY(1,1),
Genre_list varchar(50)
);


/* There are spaces at the starting of some records of Genre from IndianMovies
so, we used the trim(Leading '' FROM col) function to remove space at start of the column and then
inserted those records into the Genre table that we created*/
INSERT INTO Genre
SELECT DISTINCT TRIM(LEADING ' ' FROM Genre_list) AS Genre_List FROM IndianMovies;


-- To remove the leading spaces in the Genre_list column in IndianMovies table
UPDATE IndianMovies
SET Genre_list = LTRIM(Genre_list)
WHERE Genre_list LIKE ' %'


-- Adding Genre_ID column to IndianMovies Table
ALTER TABLE IndianMovies
ADD Genre_ID Int;


-- Map the Genre & IndianMovies Table and update the Genre_ID col
UPDATE IndianMovies
SET IndianMovies.Genre_ID = Genre.Genre_ID
FROM Genre
JOIN IndianMovies ON IndianMovies.Genre_list = Genre.Genre_list;


--Since we moved the Genrelist to a diff. table, We are removing it from this IndianMovies Table
ALTER TABLE IndianMovies
DROP COLUMN Genre_List;


-- Now, we will split the IndianMovies table further into Language Table. So, we create the table first.
CREATE TABLE Languages (
Language_ID INT PRIMARY KEY IDENTITY (1,1),
Language_name nvarchar(30)
);


-- Insert the distinct languages records from IndianMovies table to Languages table
INSERT INTO Languages
SELECT DISTINCT Language as Language_List FROM IndianMovies;


-- Now, create a Language_ID col in IndianMovies table and then update the ID col and remove the language col.
ALTER TABLE IndianMovies
ADD Language_ID int;

UPDATE IndianMovies
SET Language_ID = L.Language_ID
FROM Languages L
JOIN IndianMovies Ind ON Ind.Language = L.Language_name;

ALTER TABLE IndianMovies
DROP COLUMN Language;


-- The year col has some spaces, special characters, etc,. We are removing them by using the below 2 functions
UPDATE IndianMovies
SET Year = CASE
			WHEN PATINDEX('%[0-9]%', Year) > 0
			THEN SUBSTRING(Year, PATINDEX('%[0-9]%', Year), LEN(Year))
			ELSE NULL
		   END
WHERE ISNUMERIC(Year) = 0;

UPDATE IndianMovies
SET Year = LEFT(Year, LEN(Year) - 1)
WHERE RIGHT(Year,1) = '– ';


-- Creating a table named Movies_List
CREATE TABLE Movies_List (
Movie_ID nvarchar(200),
Movie_name nvarchar(MAX),
Year nvarchar(200),
Timing_min nvarchar(200),
Rating_10 nvarchar(20),
Votes nvarchar(200)
)


-- Inserting the distinct records into Movies_List table from IndianMovies table
INSERT INTO Movies_List (Movie_ID, Movie_name, Year, Timing_min, Rating_10, Votes)
SELECT DISTINCT ID, Movie_name, Year, Timing_min, Rating_10, Votes FROM IndianMovies;


/* Some of the Movie_ID cols are null. Since we want to make this as a primary key, we populated the id col with values
starting with 'tt' followed by 7 numericals. The following CTE is used to populate that*/
;WITH NumberedRows AS (
	SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum
	FROM Movies_List
	WHERE Movie_ID = '-'
)
UPDATE NumberedRows
SET Movie_ID = 'tt' + RIGHT('0000000' + CAST(RowNum AS NVARCHAR(10)), 7)


--Updated the ID col in IndianMovies table to match with the Movies_List table as we populated the ID col for null values
UPDATE IndianMovies
SET ID = Movies_List.Movie_ID
FROM IndianMovies
INNER JOIN Movies_List ON IndianMovies.Movie_name = Movies_List.Movie_name;


-- Renamed the ID col from IndianMovies to Movie_ID
EXEC sp_rename 'IndianMovies.ID', 'Movie_ID', 'COLUMN';


-- Adding a new ID col and then populating the ID col starting values with Mid
ALTER TABLE IndianMovies
ADD ID NVARCHAR(10)

;WITH NumberedRow AS (
	SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum
	FROM IndianMovies
)
UPDATE NumberedRow
SET ID = 'Mid' + RIGHT('000000' + CAST(RowNum AS NVARCHAR(6)), 6)


-- First, to set the ID col as PK, we are making it not null and then making it as PK
ALTER TABLE IndianMovies
ALTER COLUMN ID NVARCHAR(10) NOT NULL;

ALTER TABLE IndianMovies
ADD CONSTRAINT PK_IndianMovies_ID PRIMARY KEY(ID)


-- Dropping the following cols as we already have them in Movies_List table
ALTER TABLE IndianMovies
DROP COLUMN Movie_name, Year, Timing_min, Rating_10, Votes;


-- First, to set the Movie_ID col as PK, we are making it not null and then making it as PK
ALTER TABLE Movies_List
ALTER COLUMN Movie_ID NVARCHAR(200) NOT NULL;

ALTER TABLE Movies_List
ADD CONSTRAINT PK_Movies_List_Movie_ID PRIMARY KEY(Movie_ID)


-- Checking the list of Duplicate Movie_ID columns from Movies_List
SELECT Movie_ID, COUNT(*) AS DUPLICATECount FROM Movies_List GROUP BY Movie_ID HAVING COUNT(*) > 1


-- After identifying the duplicate columns, we are now deleting those duplicate rows
;WITH CTE AS (
	SELECT *, ROW_NUMBER() OVER (PARTITION BY Movie_ID ORDER BY (SELECT NULL)) AS Rownum
	FROM Movies_List
)
DELETE FROM CTE
WHERE Rownum > 1;


/* Since there are issues while doing queries, I want to drop the col genre_id from IndianMovies table and instead
create a new table moviegenres with movie_id and the genre_id as the cols */

CREATE TABLE MovieGenres (
Movie_ID nvarchar(200),
Genre_ID int);


ALTER TABLE MovieGenres 
ADD CONSTRAINT FK_MovieGenres_GenreID
FOREIGN KEY (Genre_ID)
REFERENCES Genre(Genre_ID);

INSERT INTO MovieGenres (Movie_ID, Genre_ID)
SELECT Movie_ID, Genre_ID FROM IndianMovies;


ALTER TABLE IndianMovies
DROP COLUMN Genre_ID

WITH CTE AS (
    SELECT Movie_ID, Language_ID, ID,
           ROW_NUMBER() OVER (PARTITION BY Movie_ID, Language_ID ORDER BY ID) AS rn
    FROM IndianMovies
)
DELETE FROM CTE
WHERE rn > 1;

-- Select * Queries for all the tables created.
SELECT * FROM Indian_movies;
SELECT * FROM IndianMovies;
SELECT * FROM Movies_List;
SELECT * FROM Languages;
SELECT * FROM Genre;
SELECT * FROM MovieGenres;

/*
Top 10 Rating Films based on Language?
Top 10 Genres in the movies list?
Top 10 Genres according to the languages?
Top 10 Votes in the movies list?
Top 10 Votes according to the languages?
How many films are there in this dataset in each language?
What are the most genres in each language films (What language does what genres maximum)
How many films are releasing over the years?
Which films got the highest Rating?
Which films got the highest votes?
Which language films got the highest Rating?
Which language films got the highest Votes?
What is the avg run time acc. based on the Languages?
Which films got the highest rating and votes?
What is the avg runtime for the films? */



-- Top 10 Rated Films based on Language
WITH Ranked as
(
SELECT M.Movie_ID, M.Movie_name, M.Year, M.Rating_10, L.Language_name,
ROW_NUMBER () OVER (PARTITION BY L.Language_name ORDER BY M.Rating_10 DESC) as Rank
FROM Movies_List M JOIN IndianMovies I ON M.Movie_ID = I.Movie_ID
JOIN Languages L ON L.Language_ID = I.Language_ID
)
SELECT Movie_ID, Movie_name, Year, Rating_10, Language_name
FROM Ranked
WHERE Rank <=10
ORDER BY Language_name, Rating_10 DESC;

-- Top 10 Genres in the movies_list
SELECT TOP 10 G.Genre_list, COUNT(G.Genre_list) as Genre_count
FROM Genre G JOIN MovieGenres MG ON G.Genre_ID = MG.Genre_ID
JOIN Movies_List M ON MG.Movie_ID = M.Movie_ID
WHERE G.Genre_list <> '-'
GROUP BY G.Genre_list
ORDER BY Genre_count DESC

-- Top 10 Genres for each Language in the movies_list
WITH Ranked as
(
SELECT G.Genre_list, COUNT(G.Genre_list) as Genre_count, L.Language_name,
ROW_NUMBER () OVER (PARTITION BY L.Language_name ORDER BY COUNT(G.Genre_list) DESC) as Rank
FROM Genre G JOIN MovieGenres MG ON G.Genre_ID = MG.Genre_ID
JOIN Movies_List M ON MG.Movie_ID = M.Movie_ID
JOIN IndianMovies I ON I.Movie_ID = M.Movie_ID
JOIN Languages L ON L.Language_ID = I.Language_ID
WHERE G.Genre_list <> '-'
GROUP BY G.Genre_list, L.Language_name
)
SELECT Genre_list, Genre_count, Language_name
FROM Ranked
WHERE Rank <=10
ORDER BY Language_name ASC, Genre_count DESC

-- Top 10 Votes in the Movies_list
SELECT TOP 10 Movie_ID, Movie_name, Year, CONVERT(BIGINT, REPLACE(Votes, ',', '')) AS Votes
FROM Movies_List
WHERE TRY_CONVERT(BIGINT, REPLACE(Votes, ',', '')) IS NOT NULL  -- Filter out non-numeric or invalid values
ORDER BY CONVERT(BIGINT, REPLACE(Votes, ',', '')) DESC;

-- Top 10 Votes according to the Language in the Movies_list
WITH Ranked as
(
SELECT M.Movie_ID, M.Movie_name, M.Year, L.Language_name, CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) AS Votes,
ROW_NUMBER () OVER (PARTITION BY L.Language_name ORDER BY CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) DESC) as Rank
FROM Movies_List M JOIN IndianMovies I ON M.Movie_ID = I.Movie_ID
JOIN Languages L ON L.Language_ID = I.Language_ID
WHERE TRY_CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) IS NOT NULL  -- Filter out non-numeric or invalid values
)
SELECT Movie_ID, Movie_name, Year, Language_name, Votes
FROM Ranked
WHERE Rank <=10
ORDER BY Language_name ASC, CONVERT(BIGINT, REPLACE(Votes, ',', '')) DESC;

-- Count of Films according to Language in the IndianMovies dataset
SELECT L.Language_name, COUNT(M.Movie_name) as Movies_count
FROM Movies_List M JOIN IndianMovies I ON M.Movie_ID = I.Movie_ID
JOIN Languages L ON I.Language_ID = L.Language_ID
GROUP BY L.Language_name
ORDER BY L.Language_name;

-- Most genres in each language films (What genre is the maximum for each language)
WITH Ranked as
(
SELECT L.Language_name, COUNT(G.Genre_list) as Genre_count, G.Genre_list,
ROW_NUMBER () OVER (PARTITION BY L.Language_name ORDER BY COUNT(G.Genre_list) DESC) as Rank
FROM Genre G JOIN MovieGenres MG ON G.Genre_ID = MG.Genre_ID
JOIN Movies_List M ON MG.Movie_ID = M.Movie_ID
JOIN IndianMovies I ON I.Movie_ID = M.Movie_ID
JOIN Languages L ON L.Language_ID = I.Language_ID
WHERE G.Genre_list <> '-'
GROUP BY G.Genre_list, L.Language_name
)
SELECT Language_name, Genre_count, Genre_list
FROM Ranked
WHERE Rank <=1
ORDER BY Language_name ASC, Genre_count DESC

-- How many films are releasing over the years?
SELECT M.Year, COUNT(M.Movie_name) as Film_count
FROM Movies_List M
WHERE M.Year IS NOT NULL AND M.Year LIKE '[0-9][0-9][0-9][0-9]'
GROUP BY M.Year
ORDER BY M.Year

-- Which films got the highest Rating?
SELECT TOP 10 M.Movie_ID, M.Movie_name, M.Rating_10, L.Language_name
FROM Movies_List M JOIN IndianMovies I ON M.Movie_ID = I.Movie_ID
JOIN Languages L ON I.Language_ID = L.Language_ID
ORDER BY M.Rating_10 DESC

-- Which films got the highest votes?
SELECT TOP 10 M.Movie_ID, M.Movie_name, CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) AS Votes, L.Language_name
FROM Movies_List M JOIN IndianMovies I ON M.Movie_ID = I.Movie_ID
JOIN Languages L ON I.Language_ID = L.Language_ID
WHERE TRY_CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) IS NOT NULL
ORDER BY CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) DESC

-- What are the highest rating films for each Language?
WITH Ranked as
(
SELECT M.Movie_ID, M.Movie_name, M.Rating_10, L.Language_name,
ROW_NUMBER () OVER (PARTITION BY L.Language_name ORDER BY M.Rating_10 DESC) as Rank
FROM Movies_List M JOIN IndianMovies I ON M.Movie_ID = I.Movie_ID
JOIN Languages L ON I.Language_ID = L.Language_ID
)
SELECT Movie_ID, Movie_name, Rating_10, Language_name
FROM Ranked
WHERE Rank<=1
ORDER BY Language_name ASC, Rating_10 DESC
-- What are the highest voted films for each Language?
WITH Ranked as
(
SELECT M.Movie_ID, M.Movie_name, CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) AS Votes, L.Language_name,
ROW_NUMBER () OVER (PARTITION BY L.Language_name ORDER BY CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) DESC) as Rank
FROM Movies_List M JOIN IndianMovies I ON M.Movie_ID = I.Movie_ID
JOIN Languages L ON I.Language_ID = L.Language_ID
WHERE TRY_CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) IS NOT NULL
)
SELECT Movie_ID, Movie_name, Votes, Language_name
FROM Ranked
WHERE Rank <=1
ORDER BY Language_name ASC, CONVERT(BIGINT, REPLACE(Votes, ',', '')) DESC

-- What is the avg run time of films for each Language?
SELECT L.Language_name, 
AVG(CAST(LEFT(REPLACE(Timing_min, ',', ''), CHARINDEX(' ', REPLACE(Timing_min, ',', ''))) AS int)) as AvgRuntime
FROM Movies_List M JOIN IndianMovies I ON M.Movie_ID = I.Movie_ID
JOIN Languages L ON I.Language_ID = L.Language_ID
WHERE ISNUMERIC(LEFT(REPLACE(Timing_min, ',', ''), CHARINDEX(' ', REPLACE(Timing_min, ',', '')))) = 1
GROUP BY L.Language_name
ORDER BY L.Language_name ASC;

-- Which films got the highest rating and votes?
WITH Ranked as
(
SELECT M.Movie_ID, M.Movie_name, M.Rating_10, CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) AS Votes, L.Language_name,
ROW_NUMBER () OVER (PARTITION BY L.Language_name ORDER BY M.Rating_10 DESC, CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) DESC) as Rank
FROM Movies_List M JOIN IndianMovies I ON M.Movie_ID = I.Movie_ID
JOIN Languages L ON I.Language_ID = L.Language_ID
WHERE TRY_CONVERT(BIGINT, REPLACE(M.Votes, ',', '')) IS NOT NULL
)
SELECT Movie_ID, Movie_name, Rating_10, Votes, Language_name
FROM Ranked
WHERE Rank <=10
ORDER BY Language_name ASC, Rating_10 DESC, CONVERT(BIGINT, REPLACE(Votes, ',', '')) DESC;



-- What is the avg runtime for the films?
SELECT
AVG(CAST(LEFT(REPLACE(Timing_min, ',', ''), CHARINDEX(' ', REPLACE(Timing_min, ',', ''))) AS int)) as AvgRuntime
FROM Movies_List M JOIN IndianMovies I ON M.Movie_ID = I.Movie_ID
JOIN Languages L ON I.Language_ID = L.Language_ID
WHERE ISNUMERIC(LEFT(REPLACE(Timing_min, ',', ''), CHARINDEX(' ', REPLACE(Timing_min, ',', '')))) = 1;



/* Top 10 Rated Movies for each Language using the Indian_Movies Table
WITH Ranked as
(
SELECT ID, Movie_name, Rating_10, Votes, Language,
ROW_NUMBER () OVER (PARTITION BY Language ORDER BY Rating_10 DESC) as Rank
FROM Indian_movies
)
SELECT ID, Movie_name, Rating_10, Votes, Language
FROM Ranked
WHERE Rank <=10
ORDER BY Language, Rating_10 DESC;


-- Top 10 Genres for each language
WITH Ranked as
(
SELECT Genre, Count(Genre) as Genre_count, Language,
ROW_NUMBER () OVER (PARTITION BY Language ORDER BY Genre DESC) as Rank
FROM Indian_movies
GROUP BY Genre, Language
)
SELECT Genre, Genre_count, Language
FROM Ranked
WHERE Rank <=10
ORDER BY Language ASC, Genre_count DESC;


-- Top 10 Genres in the Movies_List
SELECT TOP 10 Genre, COUNT(Genre) as Genre_count
FROM Indian_movies
WHERE Genre <> '-'
GROUP BY Genre
ORDER BY Genre_count DESC;


--Top 10 Voted in the Movies_List
SELECT Movie_Name, max(Votes)
FROM Indian_movies
GROUP BY Movie_Name
ORDER BY max(votes) DESC
*/