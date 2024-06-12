-- Selecionando os registros não nulos e válidos
CREATE TEMPORARY TABLE ValidRecords AS
SELECT datahora, datahora_captura, placa, velocidade, camera_latitude, camera_longitude
FROM rj-cetrio.desafio.readings_2024_06
WHERE datahora IS NOT NULL 
    AND datahora_captura IS NOT NULL 
    AND placa IS NOT NULL 
    AND empresa IS NOT NULL 
    AND tipoveiculo IS NOT NULL 
    AND velocidade IS NOT NULL 
    AND camera_numero IS NOT NULL 
    AND camera_latitude IS NOT NULL 
    AND camera_longitude IS NOT NULL
    -- eliminando os erros de leituras de velocidade dos radares = 0
    AND velocidade != 0.0
    -- eliminando os erros de posicionamento dos radares
    AND camera_latitude != 0.0 
    AND camera_longitude != 0.0;

--Identificando as leituras de placas duplicadas
CREATE TEMPORARY TABLE Duplicates AS
SELECT *
FROM ValidRecords
GROUP BY datahora, datahora_captura, placa, velocidade, camera_latitude, camera_longitude
HAVING COUNT(placa) > 1;

-- Calculando a distância entre os pontos de observação
CREATE TEMPORARY TABLE DistanceCalculation AS
SELECT 
-- calculando a diferença de tempo entre duas obserções de placas (em segundos)
    t1.placa,
    t1.datahora AS datahora1,
    t2.datahora AS datahora2,
    timestamp_diff(t2.datahora, t1.datahora, second) AS dt_int,
-- calculando a distância entre os radares que capturaram as placas
    t1.camera_latitude AS lat1,
    t1.camera_longitude AS lon1,
    t2.camera_latitude AS lat2,
    t2.camera_longitude AS lon2,
    ST_DISTANCE(ST_GEOGPOINT(t1.camera_longitude, t1.camera_latitude), ST_GEOGPOINT(t2.camera_longitude, t2.camera_latitude))/1000 AS distancia,
-- utilizando a maior velocidade observada como parâmetro para calcular o tempo de deslocamento entre os radares
    GREATEST(t1.velocidade, t2.velocidade) AS max_velocidade
FROM
    Duplicates t1
-- fazendo o join para selecionar apenas as placas duplicadas
JOIN
    Duplicates t2
ON
    t1.placa = t2.placa
WHERE
    t1.datahora < t2.datahora;

-- Calculando dt_calc (intervalo de tempo calculado entre os radares na maior velocidade registrada)
CREATE TEMPORARY TABLE FinalCalculation AS
SELECT 
    *,
    distancia / max_velocidade AS dt_calc
FROM
    DistanceCalculation;

-- Filtrando as placas onde dt_int < dt_calc (o intervalo de tempo entre as observações é menor que o intervalo calculado)
SELECT 
    placa, datahora1, datahora2, dt_int, distancia, max_velocidade, dt_calc, lat1, lon1, lat2, lon2
FROM 
    FinalCalculation
WHERE 
    (dt_int/360) < dt_calc
    AND distancia != 0;

-- Limpando as tabelas temporárias
DROP TABLE IF EXISTS ValidRecords;
DROP TABLE IF EXISTS Duplicates;
DROP TABLE IF EXISTS DistanceCalculation;
DROP TABLE IF EXISTS FinalCalculation;
-- As placas selecionadas foram baseadas na velocidade máxima observada. Foram encontradas duas placas clonadas. Na tabela pode ser observado que a primeira placa foi obseravada a uma distância de 1,25km com um intervalo de 1 seegundo. A segunda placa foi obervado por radares distantes 4km com um intervalo de 23 segundos.