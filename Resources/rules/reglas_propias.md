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
  - No se traslada una matrícula que ya tiene ausencias, notas o informes CAS: pertenecen a las asignaciones de su sección y quedarían fuera de la nueva (MA008).
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
- RN-68: Al registrar o modificar la lección se indican los estudiantes ausentes y los que llegaron tarde. Cada uno debe estar matriculado en la sección a esa fecha: matrícula en o antes de la fecha y sin retiro en o antes de ella (LE003). Modificar la lección reemplaza las listas; la justificación de quien sigue ausente se conserva.
- RN-86: Las llegadas tardías se registran por lección como las ausencias; un estudiante no puede estar ausente y tardío en la misma lección (LE004). Una tardía no se justifica (NF011) y no suma al porcentaje de ausentismo: se cuenta aparte (así sale en el reporte de bandas: tardías, injustificadas y justificadas).
- RN-69: El mismo profesor de la asignación justifica una ausencia, con un motivo, o anula la justificación (Visión 5.9). NF011 si el estudiante no tiene ausencia en esa lección.
- RN-70: El resumen de ausentismo de una asignación compara, por estudiante, sus ausencias (justificadas e injustificadas) con las lecciones registradas mientras estuvo matriculado (desde su fecha de matrícula hasta su retiro), y muestra sus tardías. Se puede filtrar por semestre.
- RN-71: El guía consulta el resumen de ausentismo de su sección por estudiante y asignatura (AD005 si no es el guía de la sección).
- RN-72: No se elimina una asignación con lecciones ni una matrícula con ausencias (23001).

### Evaluaciones
- RN-73: El tipo de asignatura define la escala de la nota: SUPERIOR (mínima 4) y MEDIO (mínima 3) con bandas 1 a 7; TRONCAL (TdC, Monografía, CAS) con letras A a E ('A' la más alta, sin mínima); MEP con enteros de 0 a 100 (mínima 70). Una nota fuera de la escala da EV001. El tipo de una asignatura con notas o monografías no se cambia (AS006).
- RN-74: La nota es por semestre, estudiante y asignación. El profesor la registra y corrige desde el inicio del semestre (EV002) hasta el cierre: la fecha de fin del semestre o, si el ADMIN le dio una prórroga, la fecha límite de esa prórroga (EV003). La prórroga es por profesor y semestre, posterior al fin del semestre y no pasada (EV007).
- RN-75: Se califica a los estudiantes matriculados en la sección a más tardar el fin del semestre y sin retiro en o antes de esa fecha (EV004). El profesor envía al guía las notas de su asignación cuando todos tienen nota (EV006); el guía y el reporte de bandas solo ven notas enviadas. Después del envío el profesor puede corregir hasta el cierre; eliminar una nota anula el envío (hay que volver a enviar). Cada nota lleva observaciones opcionales del profesor (Profesor Regular CU09). No se elimina una asignación o matrícula con notas (23001).
- RN-76: La pantalla principal del profesor muestra sus asignaciones con el plazo de notas abierto, los días para el cierre y un aviso mientras le falten notas o no las haya enviado: informativo desde 30 días antes y de prioridad desde 15 días antes.
- RN-77: Las notas de una sección se consultan con un solo caso de uso (Guía CU03 y CU04 unificados): cualquier guía consulta las notas enviadas de cualquier sección; el profesor consulta las de sus asignaciones.

### Monografía
- RN-78: Una monografía por estudiante (MO001). Empieza con su matrícula de nivel 10 sin retiro (MO004) y sigue en su nivel 11 (dura los dos años: 6 meses de capacitación y 1.5 años de tutoría). El ADMIN la asigna a un coordinador con rol COORD_MONOGRAFIA (MO005) en una materia SUPERIOR o MEDIO (MO002); cada coordinador tiene grupos de 1 a 5 estudiantes por materia y cohorte (MO003). No se quita COORD_MONOGRAFIA a quien coordina monografías sin terminar (AU019).
- RN-79: Estados: CAPACITACION, INVESTIGACION y TERMINADA. Solo el coordinador de la monografía los cambia (AD006). TERMINADA es un estado final: no se reabre (MO007, decisión del 01/10/2026).
- RN-80: El seguimiento son observaciones fechadas del coordinador (no futuras ni anteriores al inicio de la monografía, MO006). "Verificar" (Guía CU07) es que el guía consulte el estado y el seguimiento de las monografías de su sección.
- RN-81: Cada semestre el coordinador envía al guía un reporte con observaciones (Coordinador CU05), en el plazo de notas del semestre (con su prórroga si la tiene). Sale en el reporte de bandas del estudiante: área (materia), coordinador y observaciones ("Sin informe registrado" si no hay). Una monografía con seguimiento o reportes no se elimina (23001).
- RN-88: La monografía también puede tener su asignatura TRONCAL (código MON, registrada por el ADMIN): se asigna a la sección como cualquier asignatura y el profesor asignado (puede ser un coordinador) registra y envía su nota. Así sale en la lista de asignaturas TRONCAL del reporte de bandas y, además, en la sección de monografía (RN-81).

### CAS
- RN-82: CAS es la asignatura TRONCAL con código CAS. El profesor CAS se asigna a la sección con una asignación académica de CAS (Administrador CU38 = CU30), y debe tener el rol PROFESOR_CAS en periodos no finalizados (AD007). No se quita PROFESOR_CAS a quien imparte CAS en un periodo no finalizado (AU018). La asignatura CAS siempre es TRONCAL (AS008).
- RN-83: Cada semestre el profesor CAS llena un informe por estudiante con el formato del Instituto: experiencias (descripción, fecha, C/A/S, resultados de aprendizaje 1 a 7, carpeta, reflexión y pruebas), perfil y entrevistas (I, II y final: lo que lleva hasta ese semestre) y observaciones. Se llena en el plazo de notas del semestre (EV002/EV003) para estudiantes que se califican (EV004); la fecha de una experiencia no es futura y cae en el periodo (CA001). El informe comparte la clave de la nota CAS (asignación, matrícula, semestre): la nota se registra y envía con evaluaciones.
- RN-84: El coordinador CAS consulta el progreso de todas las secciones (quién tiene informe, experiencias, perfil y entrevistas) y genera el reporte CAS de un estudiante; la nota CAS solo aparece si el profesor ya la envió.

### Informes
- RN-85: El guía genera el reporte de bandas de un estudiante o de toda su sección guía en un semestre (AD005): por asignatura, banda o nota mínima, nota alcanzada (solo si se envió), ausentismo (tardías, injustificadas y justificadas) y observaciones del profesor; las asignaturas se agrupan en BI (SUPERIOR y MEDIO), TRONCAL y MEP, más la sección de monografía (RN-81). CAS no va en este reporte (tiene su informe, RN-83). El backend devuelve los datos y el front arma el PDF (el formato es el del ejemplo del Instituto).

### Roles
- RN-13: Roles válidos: ADMIN, PROFESOR_REGULAR (profesor de asignatura), GUIA (profesor guía de sección), COORD_MONOGRAFIA, PROFESOR_CAS y COORD_CAS. Asignar profesores como coordinadores (CU39) es otorgarles COORD_MONOGRAFIA o COORD_CAS.

## Aplazadas
Reglas aceptadas que el usuario decidió no implementar por ahora (no tienen módulo).

### Correo
- PR-17: Un módulo futuro enviaría por correo a los estudiantes los documentos que se ocupen, a su correo registrado aunque no usen el sistema (Profesor Regular CU13). Se descarta por ahora (decisión del 30/09/2026); falta definir qué documentos y el servidor de correo.

## Descartadas
- PR-09: Estudiantes y encargados no usan el sistema (no son usuarios, ni siquiera de consulta).
