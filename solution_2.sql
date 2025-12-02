-- =============================================
-- ЧАСТЬ 1: СОЗДАНИЕ СХЕМЫ RAW_DATA
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
-- ЧАСТЬ 2: ТЕСТОВЫЕ ДАННЫЕ ДЛЯ RAW_DATA.SALES
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
-- ЧАСТЬ 3: СОЗДАНИЕ НОРМАЛИЗОВАННОЙ СХЕМЫ CAR_SHOP
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
    model_name VARCHAR(100) NOT NULL,
    gasoline_consumption NUMERIC(4,1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(brand_id, model_name)
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
-- ЧАСТЬ 4: НАПОЛНЕНИЕ НОРМАЛИЗОВАННЫХ ТАБЛИЦ ДАННЫМИ
-- =============================================

-- Вспомогательные функции для разбора поля auto
CREATE OR REPLACE FUNCTION extract_brand(auto_text TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN split_part(auto_text, ' ', 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION extract_model(auto_text TEXT)
RETURNS TEXT AS $$
DECLARE
    parts TEXT[];
BEGIN
    parts := string_to_array(auto_text, ' ');
    RETURN array_to_string(parts[2:array_length(parts, 1)-1], ' ');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION extract_color(auto_text TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN trim(split_part(auto_text, ',', 2));
END;
$$ LANGUAGE plpgsql;

-- Заполнение стран
INSERT INTO countries (name) 
SELECT 'Russia' UNION SELECT 'Germany' UNION SELECT 'South Korea' UNION SELECT 'USA'
ON CONFLICT (name) DO NOTHING;

-- Заполнение цветов
INSERT INTO colors (name) 
SELECT 'grey' UNION SELECT 'red' UNION SELECT 'pink' UNION SELECT 'blue' 
UNION SELECT 'yellow' UNION SELECT 'green' UNION SELECT 'purple' 
UNION SELECT 'orange' UNION SELECT 'white' UNION SELECT 'black'
ON CONFLICT (name) DO NOTHING;

-- Заполнение брендов
INSERT INTO brands (name, country_id) 
SELECT 'Lada', country_id FROM countries WHERE name = 'Russia'
UNION ALL SELECT 'BMW', country_id FROM countries WHERE name = 'Germany'
UNION ALL SELECT 'Hyundai', country_id FROM countries WHERE name = 'South Korea'
UNION ALL SELECT 'Audi', country_id FROM countries WHERE name = 'Germany'
UNION ALL SELECT 'Tesla', country_id FROM countries WHERE name = 'USA'
UNION ALL SELECT 'Kia', country_id FROM countries WHERE name = 'South Korea'
UNION ALL SELECT 'Porsche', country_id FROM countries WHERE name = 'Germany'
ON CONFLICT (name) DO NOTHING;

-- Заполнение покупателей из raw_data.sales
INSERT INTO customers (person_name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales
ON CONFLICT (phone) DO NOTHING;

-- Заполнение моделей автомобилей из raw_data.sales
INSERT INTO car_models (brand_id, model_name, gasoline_consumption)
SELECT DISTINCT 
    b.brand_id, 
    extract_model(s.auto) as model_name,
    s.gasoline_consumption
FROM raw_data.sales s
JOIN brands b ON b.name = extract_brand(s.auto)
ON CONFLICT (brand_id, model_name) DO NOTHING;

-- Заполнение продаж из raw_data.sales
INSERT INTO sales (customer_id, model_id, color_id, price, sale_date, discount)
SELECT 
    c.customer_id,
    cm.model_id,
    col.color_id,
    s.price,
    s.date,
    s.discount
FROM raw_data.sales s
JOIN customers c ON s.phone = c.phone
JOIN brands b ON b.name = extract_brand(s.auto)
JOIN car_models cm ON cm.brand_id = b.brand_id AND cm.model_name = extract_model(s.auto)
JOIN colors col ON col.name = extract_color(s.auto);

-- =============================================
-- ЧАСТЬ 5: ЗАПРОСЫ К НОРМАЛИЗОВАННЫМ ТАБЛИЦАМ
-- =============================================

-- 1. Процент моделей машин без параметра gasoline_consumption
SELECT 
    ROUND(
        (COUNT(DISTINCT cm.model_id) FILTER (WHERE cm.gasoline_consumption IS NULL) * 100.0 / 
        NULLIF(COUNT(DISTINCT cm.model_id), 0)), 
        2
    ) as electric_cars_percentage
FROM car_shop.car_models cm;

-- 2. Название бренда и средняя цена по годам с учётом скидки
SELECT 
    b.name as brand,
    EXTRACT(YEAR FROM s.sale_date) as year,
    ROUND(AVG(s.price), 2) as avg_price_with_discount
FROM car_shop.sales s
JOIN car_shop.car_models cm ON s.model_id = cm.model_id
JOIN car_shop.brands b ON cm.brand_id = b.brand_id
WHERE s.price IS NOT NULL
GROUP BY b.name, EXTRACT(YEAR FROM s.sale_date)
ORDER BY b.name ASC, year ASC;

-- 3. Средняя цена всех автомобилей по месяцам в 2022 году с учётом скидки
SELECT 
    EXTRACT(MONTH FROM s.sale_date) as month,
    EXTRACT(YEAR FROM s.sale_date) as year,
    ROUND(AVG(s.price), 2) as price_avg
FROM car_shop.sales s
WHERE EXTRACT(YEAR FROM s.sale_date) = 2022 
  AND s.price IS NOT NULL
GROUP BY EXTRACT(MONTH FROM s.sale_date), EXTRACT(YEAR FROM s.sale_date)
ORDER BY month ASC;

-- 4. Список купленных машин у каждого пользователя через запятую
SELECT 
    c.person_name as person,
    STRING_AGG(b.name || ' ' || cm.model_name, ', ') as cars
FROM car_shop.sales s
JOIN car_shop.customers c ON s.customer_id = c.customer_id
JOIN car_shop.car_models cm ON s.model_id = cm.model_id
JOIN car_shop.brands b ON cm.brand_id = b.brand_id
GROUP BY c.person_name
ORDER BY c.person_name ASC;

-- 5. Самая большая и самая маленькая цена продажи автомобиля с разбивкой по стране без учёта скидки
SELECT 
    co.name as brand_origin,
    ROUND(MAX(s.price / (1 - s.discount/100)), 2) as price_max,
    ROUND(MIN(s.price / (1 - s.discount/100)), 2) as price_min
FROM car_shop.sales s
JOIN car_shop.car_models cm ON s.model_id = cm.model_id
JOIN car_shop.brands b ON cm.brand_id = b.brand_id
JOIN car_shop.countries co ON b.country_id = co.country_id
WHERE s.price IS NOT NULL 
  AND s.discount IS NOT NULL 
  AND s.discount < 100
GROUP BY co.name
ORDER BY co.name ASC;

-- 6. Количество всех пользователей из США (телефон начинается на +1)
SELECT 
    COUNT(DISTINCT c.customer_id) as persons_from_usa_count
FROM car_shop.customers c
WHERE c.phone LIKE '+1%';