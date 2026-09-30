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
- RN-62: Una sección de nivel 11 en el año X solo se crea si existe la sección de nivel 10 con el mismo número en X-1 (SE005). Mientras exista esa 11-N, la 10-N del año anterior no se elimina (SE006).
- RN-63: Al subir la sección a nivel 11 el profesor guía no se hereda: la 11-N nace sin guía y el ADMIN asigna uno (puede ser el mismo u otro).
- RN-64: Matricular en nivel 11 se puede hacer de dos formas: estudiante por estudiante (CU22) o "subiendo la sección": una acción que matricula en la 11-N de X a todos los estudiantes sin retiro de la 10-N de X-1 (crea la 11-N si no existe). Quien ya tiene matrícula en X se omite, así que la acción se puede repetir y combinar con la individual.
- RN-01: La edad es requisito de ingreso al programa: al matricularse en nivel 10, el estudiante tiene 16 años cumplidos y menos de 20 a la fecha de inicio del periodo (ES003). No se valida al registrar al estudiante ni al pasar a nivel 11 (así se pueden digitalizar estudiantes de años anteriores y quien ingresó con 19 años puede terminar el programa).

### Calendario
- RN-25: Un periodo académico corresponde a un año y tiene exactamente dos semestres (I y II); hay como máximo un periodo por año (PA001). Las fechas cumplen inicio I < fin I < inicio II < fin II (PA002).

### Asignaturas
- RN-42: Tipos de asignatura: TRONCAL (componentes centrales BI: TdC, Monografía, CAS), SUPERIOR y MEDIO (asignaturas BI de nivel superior y medio) y MEP (asignaturas del programa nacional).
- RN-39: El nivel 11 no recibe Educación Cívica ni Estudios Sociales: se registran solo con nivel 10, y no se asignan a secciones de nivel 11 (AS005).

### Ausentismo
- RN-66: Una lección es una clase que el profesor de una asignación registra cuando la imparte: fecha, hora y un tema opcional (Visión 5.8). No depende de un horario. Solo el profesor de la asignación registra, modifica o elimina sus lecciones (AD004); no se repiten fecha y hora en la misma asignación (LE002).
- RN-67: La fecha de la lección cae dentro de un semestre del periodo de la sección y no es futura (LE001). Cuando el semestre de la lección ya terminó, la lección y sus ausencias quedan cerradas (PA004).
- RN-68: Al registrar o modificar la lección se indican los estudiantes ausentes. Cada uno debe estar matriculado en la sección a esa fecha: matrícula en o antes de la fecha y sin retiro en o antes de ella (LE003). Modificar la lección reemplaza la lista de ausentes; la justificación de quien sigue ausente se conserva.
- RN-69: El mismo profesor de la asignación justifica una ausencia, con un motivo, o anula la justificación (Visión 5.9). NF011 si el estudiante no tiene ausencia en esa lección.
- RN-70: El resumen de ausentismo de una asignación compara, por estudiante, sus ausencias (justificadas e injustificadas) con las lecciones registradas mientras estuvo matriculado (desde su fecha de matrícula hasta su retiro). Se puede filtrar por semestre.
- RN-71: El guía consulta el resumen de ausentismo de su sección por estudiante y asignatura (AD005 si no es el guía de la sección).
- RN-72: No se elimina una asignación con lecciones ni una matrícula con ausencias (23001).

### Roles
- RN-13: Roles válidos: ADMIN, PROFESOR_REGULAR (profesor de asignatura), GUIA (profesor guía de sección), COORD_MONOGRAFIA, PROFESOR_CAS y COORD_CAS. Asignar profesores como coordinadores (CU39) es otorgarles COORD_MONOGRAFIA o COORD_CAS.

## Aceptadas, pendientes de implementar
Reglas validadas por el usuario cuyos módulos (evaluaciones, monografía, CAS, correo) aún no existen. Reciben número RN-xx al implementarse.

### Evaluaciones
- PR-04: El tipo de asignatura define la escala: SUPERIOR (aprobación mínima 4) y MEDIO (aprobación mínima 3) con bandas 1 a 7; TRONCAL (TdC, Monografía, CAS) con letras A a E ('A' la más alta); MEP con nota 0 a 100. No se permiten escalas fuera de estas (Visión).
- PR-05: La nota es por semestre: cada profesor envía al guía la nota de sus estudiantes en cada asignación antes del cierre, que es la fecha de fin del semestre del periodo. Después del cierre ya no se envían ni modifican notas, salvo que el ADMIN le dé más tiempo a ese profesor (la prórroga es por profesor).
- PR-11: Mientras el profesor tenga estudiantes sin nota, su pantalla muestra cuántos días faltan para el cierre: un aviso informativo desde 30 días antes y un aviso de prioridad desde 15 días antes.
- PR-18: Las notas de una sección se consultan con un solo caso de uso (unifica Guía CU03 y CU04): el guía ve todas las asignaturas de su sección guía y el profesor ve las de sus asignaciones.

### Monografía
- PR-06: Dura 2 años: 6 meses de capacitación y 1.5 años de tutoría en la materia elegida; cada coordinador/tutor tiene grupos de 1 a 5 estudiantes por materia.
- PR-07: Solo las asignaturas SUPERIOR y MEDIO pueden elegirse como materia de monografía.
- PR-08: La monografía empieza en nivel 10 y termina en nivel 11 del mismo estudiante (sigue su continuidad BI, RN-58).
- PR-15: Estados de una monografía: CAPACITACION, INVESTIGACION y TERMINADA. El coordinador registra el estado y el seguimiento (observaciones); "verificar" (Guía CU07) es que el guía consulte cómo van las monografías de su sección y sus observaciones.

### CAS
- PR-14: CAS es una asignatura TRONCAL. El profesor CAS se asigna a la sección con una asignación académica de la asignatura CAS (Administrador CU38 = CU30). Cada semestre llena un informe con formato propio y lo envía junto con la calificación: el informe apunta al registro de la nota (ej. "el estudiante X tuvo A en CAS"). El progreso CAS es ir llenando ese informe por semestre. Mientras el formato no se defina, el informe se modela de forma genérica.

### Informes y correo
- PR-16: Los informes de notas del guía (por estudiante y por sección) se generan en PDF; el formato lo aportará el usuario con un ejemplo.
- PR-17: Un módulo futuro enviará por correo a los estudiantes los documentos que se ocupen, a su correo registrado aunque no usen el sistema.

## Descartadas
- PR-09: Estudiantes y encargados no usan el sistema (no son usuarios, ni siquiera de consulta).
