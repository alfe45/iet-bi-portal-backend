using System.Text.Json;

namespace iet_bi_portal_backend.Modules.Tablero.Models;

/// <summary>Tablero del Administrador (RP-62). Sin cursos lectivos: Periodo null y los bloques del periodo null.</summary>
public record TableroAdmin(
    PeriodoTablero? Periodo,
    List<int> AniosDisponibles,
    EstudiantesTablero? Estudiantes,
    SeccionesTablero? Secciones,
    ProfesoresTablero? Profesores,
    CargaDocenteTablero? CargaDocente,
    NotasTablero? Notas,
    MonografiasTablero? Monografias,
    List<MatriculaSeccionTablero>? MatriculaPorSeccion,
    List<AusentismoSeccionTablero>? Ausentismo,
    List<AlertaTablero> Alertas,
    List<ActividadTablero> Actividad);

/// <summary>Estado: PROGRAMADO, EN_CURSO o FINALIZADO. SemestreActual null en el receso o fuera del periodo.
/// SemestreNotas: el semestre de los bloques de notas y ausentismo. DiasParaFinSemestre: solo con un semestre en curso.</summary>
public record PeriodoTablero(int Anio, string Estado, string? SemestreActual, string SemestreNotas,
    DateOnly InicioSemestre, DateOnly FinSemestre, int? DiasParaFinSemestre);

public record EstudiantesTablero(int Matriculados, int Retirados, int Nivel11, int Nivel12);

public record SeccionesTablero(int Total, int SinGuia);

/// <summary>Profesores con cuenta. SinAsignacion: activos sin asignación ni sección guía en el año.</summary>
public record ProfesoresTablero(int Activos, int Inactivos, int SinAsignacion);

public record CargaDocenteTablero(int Asignaciones, int SeccionesSinAsignaciones);

public record NotasTablero(int Asignaciones, int Confirmadas, int CompletasSinConfirmar, int Incompletas, List<NotasNivelTablero> PorNivel);

public record NotasNivelTablero(int Nivel, int Confirmadas, int CompletasSinConfirmar, int Incompletas);

public record MonografiasTablero(int EnCurso, int Terminadas, List<MonografiasCohorteTablero> PorCohorte);

public record MonografiasCohorteTablero(int Cohorte, int Capacitacion, int Investigacion, int Terminada);

public record MatriculaSeccionTablero(string Seccion, int Nivel, int Activos, int Retirados, string? Guia);

public record AusentismoSeccionTablero(string Seccion, int Lecciones, int Injustificadas, int Justificadas, int Tardias, decimal? InjustificadasPorLeccion);

/// <summary>Codigo: SECCIONES_SIN_GUIA, SECCIONES_SIN_CAS, SIN_COORDINADOR_CAS, SIN_COORDINADOR_MONOGRAFIA,
/// ESTUDIANTES_SIN_MONOGRAFIA, NOTAS_PENDIENTES, PRORROGAS_VIGENTES. Nivel: PRIORIDAD, AVISO o INFO.
/// Detalle: secciones ("11-1") o filas (profesor, asignatura, sección… según el código).</summary>
public record AlertaTablero(string Codigo, string Nivel, int Cantidad, int? DiasParaCierre, JsonElement Detalle);

/// <summary>Acción de api.logs (códigos de log_codes.md); Registro: correo, nombre o identificador afectado.</summary>
public record ActividadTablero(string Accion, string? Usuario, string? Registro, DateTimeOffset Fecha);
