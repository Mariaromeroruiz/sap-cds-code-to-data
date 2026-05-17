#  Evolución ABAP: De los LOOPs clásicos a las Vistas CDS en S/4HANA

<div align="center">

![ABAP Cloud](https://img.shields.io/badge/ABAP_Cloud-0070F2?style=for-the-badge&logo=sap&logoColor=white)
![S/4HANA](https://img.shields.io/badge/S%2F4HANA-009B77?style=for-the-badge&logo=sap&logoColor=white)
![CDS Views](https://img.shields.io/badge/CDS_Views-7B5EA7?style=for-the-badge)
![Eclipse ADT](https://img.shields.io/badge/Eclipse_ADT-2C2255?style=for-the-badge&logo=eclipseide&logoColor=white)
![Clean Core](https://img.shields.io/badge/Clean_Core-00A86B?style=for-the-badge)

**¿Cuánto le cuesta a tu empresa seguir programando ABAP como en el año 2000?**  
Este proyecto lo mide, lo demuestra y lo resuelve con código real en S/4HANA.

</div>

---

##  El problema real en las empresas

Imagina este escenario, que ocurre a diario en miles de empresas SAP:

> *El equipo de logística necesita un informe que cruce datos de aerolíneas y sus rutas de vuelo. El desarrollador ABAP veterano lo resuelve como siempre: dos `SELECT` independientes, un `LOOP`, un `READ TABLE` por cada registro... y el servidor de aplicaciones empieza a sudar.*

Este patrón —trae todos los datos a memoria, filtra en ABAP— fue correcto durante décadas. **En S/4HANA con SAP HANA, es un antipatrón que destroza el rendimiento.**

HANA es una base de datos en memoria diseñada para procesar millones de registros en milisegundos. Pero solo lo hace si le dejas. Cuando el código clásico trae toda la tabla al servidor de aplicaciones para filtrarla ahí, estás ignorando el motor más potente del sistema y sobrecargando el que menos aguanta.

**El resultado:** informes lentos, consumo innecesario de memoria, y sistemas que se degradan a medida que crece el volumen de datos.

---

##  La solución: tres paradigmas, un mismo problema

En este proyecto implemento y comparo tres enfoques para generar **el mismo informe** — aerolíneas con sus rutas de vuelo, cruzando las tablas `/DMO/CONNECTION` y `/DMO/CARRIER` — y analizo el impacto real en rendimiento y mantenibilidad de cada uno.

| | Nivel 1: Clásico | Nivel 2: ABAP SQL moderno | Nivel 3: CDS Views |
|---|---|---|---|
| **Dónde procesa** | Servidor de aplicaciones | Base de datos HANA | Base de datos HANA |
| **Viajes a la BD** | 2 queries independientes | 1 query con JOIN | 1 SELECT a la vista |
| **Líneas de código** | ~45 líneas | ~15 líneas | ~5 líneas en main |
| **Reutilizable** | No | No | ✅ Sí — OData, Fiori, otros programas |
| **Compatible upgrades S/4HANA** | ⚠️ Riesgo | ✅ | ✅ Clean Core |

---

##  El experimento en detalle

### Nivel 1 — El enfoque clásico (el problema)

Dos `SELECT` independientes a la base de datos. La tabla de conexiones llega completa al servidor de aplicaciones. Luego un `LOOP` recorre cada registro y para cada uno lanza un `READ TABLE` buscando el nombre de la aerolínea por `carrier_id`.

```abap
" ❌ Dos queries independientes — dos viajes a la base de datos
SELECT connection_id, carrier_id, airport_from_id, airport_to_id
  FROM /dmo/connection
  INTO TABLE @DATA(lt_conexion)
  UP TO 10 ROWS.

SELECT name, carrier_id
  FROM /dmo/carrier
  INTO TABLE @DATA(lt_aerolineas)
  UP TO 10 ROWS.

" ❌ LOOP en el servidor de aplicaciones — consume CPU y memoria del app server
LOOP AT lt_conexion INTO DATA(ls_conexion).
  READ TABLE lt_aerolineas INTO DATA(ls_aerolinea)
    WITH KEY carrier_id = ls_conexion-carrier_id.
  IF sy-subrc = 0.
    ls_informe = VALUE #(
      name           = ls_aerolinea-name
      connection_id  = ls_conexion-connection_id
      airport_from_id = ls_conexion-airport_from_id
      airport_to_id  = ls_conexion-airport_to_id
    ).
    APPEND ls_informe TO lt_informe.
  ENDIF.
ENDLOOP.

out->write( lt_informe ).
```

**El problema técnico:** N registros en `lt_conexion` = N búsquedas en memoria. A escala empresarial (miles de conexiones, decenas de aerolíneas) esto no escala.

---

### Nivel 2 — ABAP SQL moderno (la mejora)

Un único `SELECT` con `JOIN` integrado. El cruce de tablas ocurre dentro de SAP HANA. El servidor de aplicaciones recibe únicamente el resultado final, ya procesado.

```abap
" ✅ Un solo viaje a la BD — el JOIN ocurre en HANA
SELECT connection_id,
       airport_from_id,
       airport_to_id,
       name
  FROM /dmo/connection AS c
  JOIN /dmo/carrier AS a ON c~carrier_id = a~carrier_id
  INTO TABLE @DATA(lt_informe)
  UP TO 10 ROWS.

IF sy-subrc = 0.
  out->write( lt_informe ).
ENDIF.
```

**La mejora:** eliminamos el `LOOP`, el `READ TABLE` y el segundo `SELECT`. El código se reduce a un tercio. HANA hace el trabajo pesado.

---

### Nivel 3 — CDS View: arquitectura Code-to-Data (la solución empresarial)

Creamos la vista `ZCDS_AEROLINEAS_18` como objeto permanente en el diccionario de datos. El JOIN vive en la definición de la vista, no en el programa. El programa principal se convierte en una línea.

**Definición de la vista CDS:**

```abap
//@AccessControl.authorizationCheck: #NOT_REQUIRED
@AbapCatalog.sqlViewName: 'ZCDS_AEROLINEAS'
@EndUserText.label: 'CDS ejercicio por libre'
@Metadata.ignorePropagatedAnnotations: true

define view ZCDS_AEROLINEAS_18
  as select from /dmo/connection as c
  join /dmo/carrier as a on c.carrier_id = a.carrier_id
{
  key c.connection_id  as Conexion,
      c.airport_from_id as Aeropuerto,
      c.airport_to_id   as ID,
      a.name            as Nombre
}
```

**Consumo desde el programa principal:**

```abap
" ✅ Una línea. El procesamiento es 100% HANA.
SELECT * FROM zcds_aerolineas_18
  INTO TABLE @DATA(lt_informe)
  UP TO 10 ROWS.

IF sy-subrc = 0.
  out->write( lt_informe ).
ENDIF.
```

**Por qué esto cambia todo:** la vista es un objeto reutilizable. Otros programas, servicios OData y aplicaciones Fiori Elements pueden consumirla directamente. Defines la lógica una vez, la usas en cualquier lugar. Eso es Clean Core.

---

##  Reflexión técnica: lo que el ejercicio no hace (y por qué importa)


En la vista implementada, el campo `carrier_id` no se incluye como clave. En el modelo de datos de vuelos de SAP, el número de conexión (por ejemplo `0001`) se repite entre distintas aerolíneas. Sin `carrier_id` como parte de la clave compuesta, la vista podría devolver registros duplicados cuando el volumen de datos es alto.

**La corrección para un entorno productivo:**

```abap
{
  key c.carrier_id      as CarrierId,   " ← clave compuesta: garantiza unicidad
  key c.connection_id   as Conexion,
      c.airport_from_id as Aeropuerto,
      c.airport_to_id   as ID,
      a.name            as Nombre
}
```

Identificar este tipo de problemas de integridad de datos en fase de diseño —antes de que lleguen a producción—

---

##  Arquitectura del proyecto

```
sap-cds-code-to-data/
├── src/
│   ├── 01_nivel_clasico/
│   │   └── ZCL_TABLAS_VUELOS_CLASICO.abap      ← LOOP + READ TABLE
│   ├── 02_nivel_abap_sql/
│   │   └── ZCL_TABLAS_VUELOS_SQL.abap          ← JOIN en SELECT
│   └── 03_nivel_cds/
│       ├── ZCDS_AEROLINEAS_18.ddls              ← definición de la vista CDS
│       └── ZCL_CONSOLA_CDS.abap                ← programa consumidor
└── README.md
```

---

##  Stack técnico

| Tecnología | Uso en el proyecto |
|---|---|
| `ABAP Cloud` | Desarrollo en entorno Clean Core |
| `CDS Views` | Modelado de datos Code-to-Data |
| `ABAP SQL` | Consultas optimizadas para SAP HANA |
| `Eclipse ADT` | Entorno de desarrollo |
| `S/4HANA` | Plataforma de ejecución |
| `/DMO/ Flight Model` | Dataset de referencia SAP (aerolíneas y vuelos) |

---

##  Resultado

Los tres enfoques devuelven el mismo resultado en consola:

```
CONEXION  AEROPUERTO  ID   NOMBRE
0001      SFO         SIN  Singapore Airlines Limited
0002      SIN         SFO  Singapore Airlines Limited
0011      NRT         SIN  Singapore Airlines Limited
0058      SFO         FRA  United Airlines, Inc.
...
```

La diferencia no está en el output. Está en **cómo llega**: cuánta memoria consumió, cuántos viajes hizo a la base de datos, si el código puede reutilizarse mañana sin tocarlo.

---

## 👩‍💻 Sobre mí

Soy **María Victoria Romero**, desarrolladora ABAP Cloud Junior formada en la Academia Experis (Junta de Andalucía, 2026). Me especializo en el stack moderno de SAP: ABAP Cloud, S/4HANA y BTP.

Cuando hay un problema, no paro hasta resolverlo — y cuando lo resuelvo, entiendo por qué funciona.

📍 Sevilla · Disponibilidad inmediata · Presencial o remoto  
🔗 [linkedin.com/in/mvromero](https://linkedin.com/in/mvromero)  
🐙 [github.com/Mariaromeroruiz](https://github.com/Mariaromeroruiz)  
📧 mariaromeroruiz95@gmail.com

---

<div align="center">
<sub>Proyecto formativo · Academia Experis · Junta de Andalucía · 2026</sub>
</div>
