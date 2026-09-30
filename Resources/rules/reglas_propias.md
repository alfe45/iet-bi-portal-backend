# Reglas propias (Instituto Dr. Clodomiro Picado Twight — programa BI)

Adaptaciones del sistema genérico de matrículas (`reglas_generales.md`) a la realidad del Instituto y del
Bachillerato Internacional. La numeración RN-xx es común con las reglas generales.

## Implementadas

### Programa BI de dos años (niveles 10 y 11)
- RN-35: El sistema solo maneja los niveles 10 y 11. Una sección se identifica por año, nivel y número (1 a 99), ej. 2026 "10-1"; no se repite en el periodo (SE001, SE002).
- RN-58: BI es un programa de dos años: el estudiante cursa nivel 10 y al año siguiente nivel 11, en la sección con el mismo número (la sección completa sube de nivel: 10-1 de 2026 pasa a ser 11-1 de 2027).
  - Para matricular en nivel 11 debe existir su matrícula de nivel 10 del año anterior, con el mismo número de sección y sin retiro (MA004).
  - No se repite un nivel: una sola matrícula de nivel 10 y una de nivel 11 por estudiante (MA005).
  - Solo se traslada de sección dentro del nivel 10 y antes de pasar a 11; en nivel 11 la sección conserva su número (MA006).
  - Una matrícula de nivel 10 que ya tiene su continuidad en nivel 11 no se retira ni se elimina; primero se corrige la de nivel 11 (MA007).
  - Consecuencia para la digitalización: se carga primero el año de nivel 10 y después el de nivel 11.
- RN-01: La edad es requisito de ingreso al programa: al matricularse en nivel 10, el estudiante tiene 16 años cumplidos y menos de 20 a la fecha de inicio del periodo (ES003). No se valida al registrar al estudiante ni al pasar a nivel 11 (así se pueden digitalizar estudiantes de años anteriores y quien ingresó con 19 años puede terminar el programa).

### Calendario
- RN-25: Un periodo académico corresponde a un año y tiene exactamente dos semestres (I y II); hay como máximo un periodo por año (PA001). Las fechas cumplen inicio I < fin I < inicio II < fin II (PA002).

### Asignaturas
- RN-42: Tipos de asignatura: TRONCAL (componentes centrales BI: TdC, Monografía, CAS), SUPERIOR y MEDIO (asignaturas BI de nivel superior y medio) y MEP (asignaturas del programa nacional).
- RN-39: El nivel 11 no recibe Educación Cívica ni Estudios Sociales: se registran solo con nivel 10, y no se asignan a secciones de nivel 11 (AS005).

### Roles
- RN-13: Roles válidos: ADMIN, PROFESOR_REGULAR (profesor de asignatura), GUIA (profesor guía de sección), COORD_MONOGRAFIA, PROFESOR_CAS y COORD_CAS. Asignar profesores como coordinadores (CU42) es otorgarles COORD_MONOGRAFIA o COORD_CAS.

## Propuestas por validar (no implementadas)
Reglas que se deducen de la Visión, el Glosario o los borradores. Márcalas como aceptadas, corrígelas o descártalas.

- PR-01 (secciones): una sección de nivel 11 en el año X solo se crea si existió la sección de nivel 10 con el mismo número en X-1 (la sección sube completa). Alternativa: permitir crearla y que las matrículas la vayan llenando.
- PR-02 (secciones): al subir la sección a 11, su profesor guía se mantiene (proponer automáticamente el mismo guía de la 10-N del año anterior).
- PR-03 (matrícula): "subir la sección": una acción que matricule en 11-N de X a todos los estudiantes no retirados de 10-N de X-1, en lugar de uno por uno.
- ACEPTADA - PR-04 (evaluaciones): el tipo de asignatura define la escala: SUPERIOR(aprobación mínima 4) y MEDIO(aprobación mínima 3) con Bandas 1 a 7; TRONCAL (TdC, Monografía, CAS) con letras A a E ('A' la más alta); MEP con nota 0 a 100. La Visión prohíbe escalas arbitrarias fuera de estas.
- ACEPTADA - PR-05 (evaluaciones): las notas no se modifican después de que el profesor guía cierra o consolida el informe, salvo permiso del ADMIN.
- ACEPTADA - PR-06 (monografía): dura 2 años: 6 meses de capacitación y 1.5 años de tutoría en la materia elegida; cada coordinador/tutor tiene grupos de 1 a 5 estudiantes por materia.
- ACEPTADA - PR-07 (monografía): solo las asignaturas SUPERIOR y MEDIO pueden elegirse como materia de monografía.
- ACEPTADA - PR-08 (monografía): la monografía empieza en nivel 10 y termina en nivel 11 del mismo estudiante (sigue su continuidad BI).
- ELIMINAR los estudiantes y encargados no usan el sistema - PR-09 (usuarios): estudiantes y encargados como usuarios de solo consulta (Visión 5.2); cada uno ve únicamente su propia información (Ley 8968).  
- ACEPTADA - PR-10 (ausentismo): la asistencia se registra por lección de una asignación docente y las ausencias pueden justificarse (Visión 5.8 y 5.9).
