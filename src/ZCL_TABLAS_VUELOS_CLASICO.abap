"! <p class="shorttext synchronized">Nivel 1 - Paradigma clásico ABAP: LOOP + READ TABLE</p>
"!
"! <p>
"!   PROPÓSITO: Demostrar el patrón clásico de acceso a datos en ABAP y
"!   sus limitaciones de rendimiento en entornos S/4HANA con SAP HANA.
"!
"!   PROBLEMA QUE REPRESENTA:
"!   Este enfoque realiza DOS viajes independientes a la base de datos y
"!   procesa el cruce de tablas en el servidor de aplicaciones mediante
"!   un LOOP + READ TABLE. En entornos con alto volumen de datos, esto
"!   genera consumo innecesario de memoria y CPU en el app server,
"!   ignorando la capacidad de procesamiento de SAP HANA.
"!
"!   TABLAS UTILIZADAS:
"!   - /DMO/CONNECTION : rutas de vuelo (connection_id, carrier_id, aeropuertos)
"!   - /DMO/CARRIER    : aerolíneas (carrier_id, name)
"!   Clave de cruce: carrier_id (campo común entre ambas tablas)
"! </p>
CLASS zcl_tablas_vuelos_clasico DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

ENDCLASS.

CLASS zcl_tablas_vuelos_clasico IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " ---------------------------------------------------------------
    " PASO 1: Definición del tipo de estructura del informe final
    " Combinamos campos de ambas tablas en una estructura propia
    " ---------------------------------------------------------------
    TYPES: BEGIN OF ty_informe,
             name            TYPE /dmo/carrier_name,
             connection_id   TYPE /dmo/connection_id,
             airport_from_id TYPE /dmo/airport_from_id,
             airport_to_id   TYPE /dmo/airport_to_id,
           END OF ty_informe.

    DATA ls_informe TYPE ty_informe.
    DATA lt_informe TYPE TABLE OF ty_informe.

    " ---------------------------------------------------------------
    " PASO 2: Primer viaje a la base de datos — tabla de conexiones
    " ❌ ANTIPATRÓN: SELECT independiente, trae datos sin cruzar
    " UP TO 10 ROWS: limitamos para la demo (en producción serían miles)
    " ---------------------------------------------------------------
    SELECT connection_id,
           carrier_id,
           airport_from_id,
           airport_to_id
      FROM /dmo/connection
      INTO TABLE @DATA(lt_conexion)
      UP TO 10 ROWS.

    " ---------------------------------------------------------------
    " PASO 3: Segundo viaje a la base de datos — tabla de aerolíneas
    " ❌ ANTIPATRÓN: segunda query independiente al mismo tiempo
    " ---------------------------------------------------------------
    SELECT name,
           carrier_id
      FROM /dmo/carrier
      INTO TABLE @DATA(lt_aerolineas)
      UP TO 10 ROWS.

    " ---------------------------------------------------------------
    " PASO 4: Cruce de datos en memoria del servidor de aplicaciones
    " ❌ ANTIPATRÓN PRINCIPAL:
    "   - LOOP itera sobre cada registro de conexiones en el app server
    "   - READ TABLE busca la aerolínea por clave para cada iteración
    "   - Con N conexiones = N búsquedas en memoria
    "   - El procesamiento ocurre en ABAP, NO en SAP HANA
    " ---------------------------------------------------------------
    LOOP AT lt_conexion INTO DATA(ls_conexion).

      READ TABLE lt_aerolineas INTO DATA(ls_aerolinea)
        WITH KEY carrier_id = ls_conexion-carrier_id.

      IF sy-subrc = 0.
        ls_informe = VALUE #(
          name            = ls_aerolinea-name
          connection_id   = ls_conexion-connection_id
          airport_from_id = ls_conexion-airport_from_id
          airport_to_id   = ls_conexion-airport_to_id
        ).
        APPEND ls_informe TO lt_informe.
      ENDIF.

    ENDLOOP.

    " ---------------------------------------------------------------
    " PASO 5: Salida por consola ADT
    " ---------------------------------------------------------------
    out->write( lt_informe ).

  ENDMETHOD.

ENDCLASS.
