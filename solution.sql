-- =============================================
-- Создание схемы raw_data и таблицы sales
-- =============================================

CREATE SCHEMA IF NOT EXISTS raw_data;

CREATE TABLE IF NOT EXISTS raw_data.sales (
    id INTEGER PRIMARY KEY,
    auto TEXT NOT NULL,
    gasoline_consumption NUMERIC(4,1),
    price NUMERIC(10,2) NOT NULL,
    date DATE NOT NULL,
    person_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    discount NUMERIC(3,1) NOT NULL DEFAULT 0,
    brand_origin TEXT
);

-- =============================================
-- Заполнение таблицы sales тестовыми данными
-- =============================================

INSERT INTO raw_data.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin) VALUES
(1, 'Tesla Model X, red', NULL, 71164.60, '2019-02-20', 'John Smith', '+1-555-123-4567', 0, 'USA'),
(2, 'BMW F80, blue', 8.3, 45032.40, '2022-10-04', 'Maria Garcia', '+1-555-234-5678', 0, 'Germany'),
(3, 'Tesla Model Y, grey', NULL, 53533.13, '2022-07-24', 'David Brown', '+1-555-345-6789', 0, 'USA'),
(4, 'Audi A3, blue', 5.7, 26491.50, '2022-03-15', 'Emma Wilson', '+49-155-123456', 0, 'Germany'),
(5, 'Hyundai Elantra, red', 5.0, 42584.06, '2022-05-29', 'James Miller', '+82-10-1234-5678', 0, 'South Korea'),
(6, 'Lada Vesta, grey', 7.3, 11243.44, '2022-01-15', 'Ivan Petrov', '+7-916-123-4567', 20, 'Russia'),
(7, 'Tesla Model 3, white', NULL, 42102.70, '2022-08-30', 'Sarah Johnson', '+1-555-456-7890', 5, 'USA'),
(8, 'Kia Rio, black', 3.1, 21674.40, '2022-11-08', 'Kim Lee', '+82-10-2345-6789', 0, 'South Korea'),
(9, 'Porsche 911, green', 12.0, 106219.60, '2022-12-09', 'Thomas Weber', '+49-155-234567', 0, NULL),
(10, 'Lada Samara, pink', 7.8, 9902.40, '2022-02-28', 'Olga Ivanova', '+7-916-234-5678', 0, 'Russia')
ON CONFLICT (id) DO NOTHING;

-- =============================================
-- Создание нормализованной схемы car_shop
-- =============================================

CREATE SCHEMA IF NOT EXISTS car_shop;

SET search_path TO car_shop;

-- Таблица стран
CREATE TABLE IF NOT EXISTS countries (
    country_id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица брендов
CREATE TABLE IF NOT EXISTS brands (
    brand_id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    country_id INTEGER NOT NULL REFERENCES countries(country_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица моделей автомобилей
CREATE TABLE IF NOT EXISTS car_models (
    model_id SERIAL PRIMARY KEY,
    brand_id INTEGER NOT NULL REFERENCES brands(brand_id),
    name VARCHAR(100) NOT NULL,
    gasoline_consumption NUMERIC(4,1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(brand_id, name)
);

-- Таблица цветов
CREATE TABLE IF NOT EXISTS colors (
    color_id SERIAL PRIMARY KEY,
    name VARCHAR(30) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица покупателей
CREATE TABLE IF NOT EXISTS customers (
    customer_id SERIAL PRIMARY KEY,
    person_name VARCHAR(100) NOT NULL,
    phone VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица продаж
CREATE TABLE IF NOT EXISTS sales (
    sale_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    model_id INTEGER NOT NULL REFERENCES car_models(model_id),
    color_id INTEGER NOT NULL REFERENCES colors(color_id),
    price NUMERIC(10,2) NOT NULL CHECK (price > 0 AND price < 10000000),
    sale_date DATE NOT NULL,
    discount NUMERIC(3,1) NOT NULL DEFAULT 0 CHECK (discount >= 0 AND discount <= 100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- Заполнение нормализованных таблиц
-- =============================================

-- Заполнение стран
INSERT INTO countries (name) VALUES 
('Russia'), ('Germany'), ('South Korea'), ('USA')
ON CONFLICT (name) DO NOTHING;

-- Заполнение цветов
INSERT INTO colors (name) VALUES 
('grey'), ('red'), ('pink'), ('blue'), ('yellow'), ('green'), ('purple'), ('orange'), ('white'), ('black')
ON CONFLICT (name) DO NOTHING;

-- Заполнение брендов
INSERT INTO brands (name, country_id) VALUES
('Lada', (SELECT country_id FROM countries WHERE name = 'Russia')),
('BMW', (SELECT country_id FROM countries WHERE name = 'Germany')),
('Hyundai', (SELECT country_id FROM countries WHERE name = 'South Korea')),
('Audi', (SELECT country_id FROM countries WHERE name = 'Germany')),
('Tesla', (SELECT country_id FROM countries WHERE name = 'USA')),
('Kia', (SELECT country_id FROM countries WHERE name = 'South Korea')),
('Porsche', (SELECT country_id FROM countries WHERE name = 'Germany'))
ON CONFLICT (name) DO NOTHING;

-- =============================================
-- ЗАПРОСЫ К ДАННЫМ
-- =============================================

-- 1. Процент моделей машин без параметра gasoline_consumption
SELECT 
    ROUND(
        (COUNT(DISTINCT auto) FILTER (WHERE gasoline_consumption IS NULL) * 100.0 / 
        NULLIF(COUNT(DISTINCT auto), 0)), 
        2
    ) as electric_cars_percentage
FROM raw_data.sales
WHERE auto IS NOT NULL;

-- 2. Название бренда и средняя цена по годам с учётом скидки
SELECT 
    split_part(auto, ' ', 1) as brand,
    EXTRACT(YEAR FROM date) as year,
    ROUND(AVG(price), 2) as avg_price_with_discount
FROM raw_data.sales
WHERE auto IS NOT NULL AND date IS NOT NULL AND price IS NOT NULL
GROUP BY split_part(auto, ' ', 1), EXTRACT(YEAR FROM date)
ORDER BY brand ASC, year ASC;

-- 3. Средняя цена всех автомобилей по месяцам в 2022 году с учётом скидки
SELECT 
    EXTRACT(MONTH FROM date) as month,
    EXTRACT(YEAR FROM date) as year,
    ROUND(AVG(price), 2) as price_avg
FROM raw_data.sales
WHERE EXTRACT(YEAR FROM date) = 2022 AND price IS NOT NULL
GROUP BY EXTRACT(MONTH FROM date), EXTRACT(YEAR FROM date)
ORDER BY month ASC;

-- 4. Список купленных машин у каждого пользователя через запятую
SELECT 
    person_name as person,
    STRING_AGG(auto, ', ') as cars
FROM raw_data.sales
WHERE person_name IS NOT NULL AND auto IS NOT NULL
GROUP BY person_name
ORDER BY person ASC;

-- 5. Самая большая и самая маленькая цена продажи автомобиля с разбивкой по стране без учёта скидки
SELECT 
    COALESCE(brand_origin, 'Unknown') as brand_origin,
    ROUND(MAX(price / (1 - discount/100)), 2) as price_max,
    ROUND(MIN(price / (1 - discount/100)), 2) as price_min
FROM raw_data.sales
WHERE price IS NOT NULL AND discount IS NOT NULL AND discount < 100
GROUP BY brand_origin
ORDER BY brand_origin ASC;

-- 6. Количество всех пользователей из США (телефон начинается на +1)
SELECT 
    COUNT(*) as persons_from_usa_count
FROM raw_data.sales
WHERE phone LIKE '+1%';