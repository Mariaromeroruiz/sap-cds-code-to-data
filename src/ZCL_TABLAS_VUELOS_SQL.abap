"! <p class="shorttext synchronized">Nivel 2 - ABAP SQL moderno: JOIN en la base de datos</p>
"!
"! <p>
"!   PROPÓSITO: Demostrar la optimización inmediata que supone usar JOIN
"!   directamente en el SELECT de ABAP SQL moderno frente al patrón clásico.
"!
"!   MEJORA RESPECTO AL NIVEL 1:
"!   - Un único viaje a la base de datos (antes eran dos)
"!   - El cruce de tablas ocurre en SAP HANA, no en el servidor de aplicaciones
"!   - Eliminamos completamente el LOOP y el READ TABLE
"!   - El código se reduce de ~45 líneas a ~15 líneas con el mismo resultado
"!
"!   TABLAS UTILIZADAS:
"!   - /DMO/CONNECTION aliasada como 'c' (tabla principal de rutas)
"!   - /DMO/CARRIER    aliasada como 'a' (tabla de aerolíneas)
"!   JOIN por: c~carrier_id = a~carrier_id
"! </p>
CLASS zcl_tablas_vuelos_sql DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

ENDCLASS.

CLASS zcl_tablas_vuelos_sql IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " ---------------------------------------------------------------
    " UN ÚNICO SELECT con JOIN integrado
    " ✅ MEJORA: el cruce ocurre dentro de SAP HANA
    "    HANA devuelve el resultado ya procesado y empaquetado.
    "    El servidor de aplicaciones solo recibe el resultado final.
    "
    " Alias 'c' = /dmo/connection (rutas)
    " Alias 'a' = /dmo/carrier    (aerolíneas)
    " Nexo del JOIN: c~carrier_id = a~carrier_id
    " ---------------------------------------------------------------
    SELECT c~connection_id,
           c~airport_from_id,
           c~airport_to_id,
           a~name
      FROM /dmo/connection AS c
      JOIN /dmo/carrier AS a ON c~carrier_id = a~carrier_id
      INTO TABLE @DATA(lt_informe)
      UP TO 10 ROWS.

    " ---------------------------------------------------------------
    " Sin LOOP. Sin READ TABLE. Sin segundo SELECT.
    " El mismo resultado, con una fracción del coste de procesamiento.
    " ---------------------------------------------------------------
    IF sy-subrc = 0.
      out->write( lt_informe ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
