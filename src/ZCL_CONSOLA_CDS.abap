"! <p class="shorttext synchronized">Nivel 3 - Consumidor de la vista CDS: Code-to-Data</p>
"!
"! <p>
"!   PROPÓSITO: Demostrar cómo el programa principal se simplifica
"!   radicalmente cuando la lógica de negocio vive en una vista CDS.
"!
"!   ESTE PROGRAMA hace exactamente lo mismo que ZCL_TABLAS_VUELOS_CLASICO
"!   (cruzar aerolíneas con sus rutas), pero el código se reduce a
"!   una sola línea de SELECT.
"!
"!   CÓMO FUNCIONA:
"!   La vista ZCDS_AEROLINEAS_18 ya contiene el JOIN entre
"!   /DMO/CONNECTION y /DMO/CARRIER. Este programa simplemente
"!   consulta la vista como si fuera una tabla más del sistema.
"!   El procesamiento ocurre 100% en SAP HANA.
"!
"!   IMPORTANTE — activar antes de ejecutar:
"!   La vista CDS (ZCDS_AEROLINEAS_18.ddls) debe estar activada
"!   con CTRL + F3 en Eclipse ADT antes de poder consultarla aquí.
"! </p>
CLASS zcl_consola_cds DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

ENDCLASS.

CLASS zcl_consola_cds IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " ---------------------------------------------------------------
    " UNA SOLA LÍNEA DE SELECT.
    " ✅ La lógica de cruce vive en la vista CDS, no aquí.
    " ✅ Este programa no sabe (ni necesita saber) cuántas tablas
    "    están implicadas ni cómo se cruzan.
    " ✅ Si mañana añadimos más campos a la vista, este SELECT
    "    los recibe automáticamente sin modificar nada aquí.
    " ---------------------------------------------------------------
    SELECT *
      FROM zcds_aerolineas_18
      INTO TABLE @DATA(lt_informe)
      UP TO 10 ROWS.

    IF sy-subrc = 0.
      out->write( lt_informe ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
