# OCLW-ADR-0003: Thin FFI minimo para enumeracion de plataformas y dispositivos

**Estado:** Aprobado
**Fecha:** 2026-02-09
**Referencia:** <INDRA_INTERNAL_POLICY_REF>

## Contexto
Se requiere un primer binding Ada-C funcional para validar ABI y link con OpenCL
sin introducir aun capas Core/Thick ni abstracciones avanzadas.

## Decision
- Crear `OpenCL.Raw.API` como thin binding de host API minima.
- Incluir tipos C compatibles via `Interfaces.C` y handles opacos basados en
  `System.Address`.
- Importar solo las funciones necesarias para enumeracion:
  `clGetPlatformIDs`, `clGetPlatformInfo`, `clGetDeviceIDs`, `clGetDeviceInfo`.
- Implementar smoke test `tests/smoke/smoke_platforms.adb` para recorrer
  plataformas y dispositivos, reportando errores OpenCL por codigo.

## Consecuencias
- Se valida integracion ABI/link en una fase temprana.
- Se mantiene complejidad baja en la capa Raw.
- Futuras funciones OpenCL se agregaran incrementalmente en el mismo paquete.

## Alternativas Consideradas
1. Esperar a una capa Core/Thick antes de exponer FFI.
2. Implementar binding completo OpenCL 1.2 de una vez.
3. Implementar subset minimo y verificable (seleccionada).

