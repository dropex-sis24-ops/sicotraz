from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    Image,
    KeepTogether,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "output" / "pdf" / "Evidencia_Avance_85_SICOTRAZ.pdf"
SHOTS = ROOT / "evidencia_capturas"
OUT.parent.mkdir(parents=True, exist_ok=True)

PAGE_W, PAGE_H = letter
LEFT = RIGHT = 0.72 * inch
TOP = 0.7 * inch
BOTTOM = 0.65 * inch

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="DocTitle", parent=styles["Title"], fontName="Helvetica-Bold",
    fontSize=16, leading=20, alignment=TA_CENTER, textColor=colors.black,
    spaceAfter=12,
))
styles.add(ParagraphStyle(
    name="DocSubtitle", parent=styles["Normal"], fontName="Helvetica-Bold",
    fontSize=11, leading=14, alignment=TA_CENTER, textColor=colors.black,
    spaceAfter=20,
))
styles.add(ParagraphStyle(
    name="H1Black", parent=styles["Heading1"], fontName="Helvetica-Bold",
    fontSize=13, leading=16, textColor=colors.black, spaceBefore=3, spaceAfter=9,
))
styles.add(ParagraphStyle(
    name="H2Black", parent=styles["Heading2"], fontName="Helvetica-Bold",
    fontSize=11, leading=14, textColor=colors.black, spaceBefore=5, spaceAfter=6,
))
styles.add(ParagraphStyle(
    name="Body10", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=10, leading=14, alignment=TA_JUSTIFY, textColor=colors.black,
    spaceAfter=7,
))
styles.add(ParagraphStyle(
    name="Small", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=8.5, leading=11, alignment=TA_LEFT, textColor=colors.black,
))
styles.add(ParagraphStyle(
    name="Caption", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=9, leading=12, alignment=TA_CENTER, textColor=colors.black,
    spaceBefore=6,
))


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.black)
    canvas.drawString(LEFT, 0.35 * inch, "SICOTRAZ - Evidencia de avance del proyecto")
    canvas.drawRightString(PAGE_W - RIGHT, 0.35 * inch, f"Página {doc.page}")
    canvas.restoreState()


frame = Frame(LEFT, BOTTOM, PAGE_W - LEFT - RIGHT, PAGE_H - TOP - BOTTOM, id="normal")
doc = BaseDocTemplate(
    str(OUT), pagesize=letter, leftMargin=LEFT, rightMargin=RIGHT,
    topMargin=TOP, bottomMargin=BOTTOM, title="Evidencia de avance 85 por ciento SICOTRAZ",
    author="Pedro Jesus Chucamani Choque",
)
doc.addPageTemplates([PageTemplate(id="main", frames=[frame], onPage=footer)])

story = []
story += [
    Spacer(1, 0.55 * inch),
    Paragraph("EVIDENCIA DE AVANCE DEL PROYECTO", styles["DocTitle"]),
    Paragraph("Registro de objetivos actividades y resultados", styles["DocSubtitle"]),
    Spacer(1, 0.2 * inch),
]

meta = [
    [Paragraph("Nombre del proyecto", styles["Body10"]), Paragraph("SICOTRAZ - Sistema para el control, digitalización y trazabilidad de ropa hospitalaria", styles["Body10"])],
    [Paragraph("Nombre del estudiante", styles["Body10"]), Paragraph("Pedro Jesus Chucamani Choque", styles["Body10"])],
    [Paragraph("Fecha", styles["Body10"]), Paragraph("11 de octubre de 2026", styles["Body10"])],
    [Paragraph("Avance declarado", styles["Body10"]), Paragraph("85 %", styles["Body10"])],
]
t = Table(meta, colWidths=[1.55 * inch, 5.2 * inch])
t.setStyle(TableStyle([
    ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#B7B7B7")),
    ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#EDEDED")),
    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ("LEFTPADDING", (0, 0), (-1, -1), 7),
    ("RIGHTPADDING", (0, 0), (-1, -1), 7),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
]))
story += [t, Spacer(1, 0.25 * inch)]
story += [
    Paragraph("Resumen del avance", styles["H1Black"]),
    Paragraph(
        "El proyecto alcanzó un avance estimado del 85 %. Se encuentran implementados los módulos principales de autenticación, usuarios, catálogos, stock, movimientos, alertas, OCR local, bajas, dashboard, reportes y sincronización. La auditoría técnica permitió corregir problemas críticos de seguridad, integridad de datos, concurrencia y funcionamiento sin conexión.",
        styles["Body10"],
    ),
    Paragraph(
        "El porcentaje restante corresponde a validación de campo con usuarios institucionales, ajustes derivados de esa validación, preparación del entorno de producción y decisiones de producto documentadas en la auditoría.",
        styles["Body10"],
    ),
]

story.append(PageBreak())
story += [
    Paragraph("1 Objetivos registrados", styles["H1Black"]),
    Spacer(1, 0.06 * inch),
    Paragraph("Objetivo general", styles["H2Black"]),
    Spacer(1, 0.03 * inch),
    Paragraph(
        "Desarrollar un sistema para el control, digitalización y trazabilidad de movimientos de ropa hospitalaria en el Hospital de Tercer Nivel, mediante tecnología OCR, con el propósito de optimizar la gestión de información y fortalecer el control de los recursos textiles institucionales.",
        styles["Body10"],
    ),
    Paragraph("Objetivos específicos", styles["H2Black"]),
    Spacer(1, 0.03 * inch),
]

specific = [
    "Analizar el proceso actual de gestión de ropa hospitalaria e identificar oportunidades de mejora y necesidades de control.",
    "Diseñar la arquitectura, la base de datos y las interfaces del sistema para una gestión eficiente de la información.",
    "Implementar un módulo de digitalización de formularios mediante OCR para automatizar el registro de recepción y entrega de prendas.",
    "Desarrollar funciones de control, consulta y trazabilidad para registrar y monitorear los movimientos de ropa hospitalaria.",
    "Generar reportes e indicadores que apoyen el control y la toma de decisiones.",
    "Validar el funcionamiento mediante pruebas operativas de registro, digitalización, consulta y seguimiento.",
]
for i, item in enumerate(specific, 1):
    story.append(Paragraph(f"{i}. {item}", styles["Body10"]))

story.append(PageBreak())
story += [Paragraph("2 Relación entre objetivos actividades y avances", styles["H1Black"])]

matrix = [[
    Paragraph("Objetivo", styles["Small"]),
    Paragraph("Actividad realizada", styles["Small"]),
    Paragraph("Avance verificable", styles["Small"]),
    Paragraph("Estado", styles["Small"]),
]]
rows = [
    ("OE1", "Levantamiento y análisis del flujo de lavandería y ropería.", "Requerimientos, reglas de negocio y backlog documentados.", "Completado"),
    ("OE2", "Diseño de arquitectura Laravel y Flutter, base de datos y pantallas por rol.", "API, aplicación móvil, migraciones y catálogos implementados.", "Avanzado"),
    ("OE3", "Implementación y mejora del OCR local.", "Lectura, normalización, revisión editable, detección de ambigüedades y 8 pruebas OCR.", "Avanzado"),
    ("OE4", "Desarrollo de stock, lotes, etapas, alertas, bajas y sincronización.", "Trazabilidad funcional con controles de concurrencia, idempotencia y permisos por área.", "Avanzado"),
    ("OE5", "Construcción de dashboard, reportes y plantillas PDF.", "Indicadores y salidas disponibles en el sistema; quedan mejoras de producto documentadas.", "Parcial alto"),
    ("OE6", "Auditoría técnica, corrección de fallos y ejecución de pruebas.", "45 pruebas backend, 11 pruebas Flutter y análisis estático sin observaciones.", "Avanzado"),
]
for row in rows:
    matrix.append([Paragraph(x, styles["Small"]) for x in row])

mt = Table(matrix, colWidths=[0.52*inch, 2.15*inch, 3.35*inch, 0.8*inch], repeatRows=1)
mt.setStyle(TableStyle([
    ("GRID", (0, 0), (-1, -1), 0.45, colors.HexColor("#B7B7B7")),
    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#D9D9D9")),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("ALIGN", (0, 1), (0, -1), "CENTER"),
    ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ("RIGHTPADDING", (0, 0), (-1, -1), 5),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
]))
story += [mt, Spacer(1, 0.18*inch)]
story += [
    Paragraph("Criterio del 85 %", styles["H2Black"]),
    Paragraph(
        "El porcentaje se sustenta en la implementación de los flujos principales y en la corrección de los hallazgos de mayor impacto. No se declara el 100 % porque aún falta validación institucional en condiciones reales, preparación de despliegue y resolución de mejoras de producto que no forman parte de las correcciones ya aplicadas.",
        styles["Body10"],
    ),
]

story.append(PageBreak())
story += [
    Paragraph("3 Auditoría y pruebas ejecutadas", styles["H1Black"]),
    Paragraph(
        "La auditoría revisó el backend Laravel y la aplicación Flutter. Se corrigieron fallos de inventario, manejo de fechas, duplicación de lotes, concurrencia, bajas, seguridad, autorización, integridad de datos, sincronización y mensajes de validación.",
        styles["Body10"],
    ),
]

checks = [
    ["Verificación", "Resultado registrado el 11 de octubre de 2026"],
    ["Pruebas backend", "45 de 45 aprobadas - 242 aserciones"],
    ["Pruebas Flutter", "11 de 11 aprobadas"],
    ["Análisis estático Flutter", "Sin observaciones"],
    ["Hallazgos críticos auditados", "Corregidos los cinco problemas de mayor impacto"],
    ["Seguridad e integridad", "Controles de permisos, límites, unicidad e índices reforzados"],
]
ct = Table([[Paragraph(c, styles["Small"]) for c in row] for row in checks], colWidths=[2.1*inch, 4.7*inch])
ct.setStyle(TableStyle([
    ("GRID", (0, 0), (-1, -1), 0.45, colors.HexColor("#B7B7B7")),
    ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#EDEDED")),
    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ("TOPPADDING", (0, 0), (-1, -1), 7),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
]))
story += [ct, Spacer(1, 0.18*inch)]
story += [
    Paragraph("Pendientes reales", styles["H2Black"]),
    Paragraph(
        "Validación de campo con usuarios reales; revisión previa a la migración de producción; protección privada de fotografías; ajuste del modelo de alertas para reportes comparables; definición del alcance offline definitivo; y optimización de consultas de reportes.",
        styles["Body10"],
    ),
]

evidence = [
    ("01_inicio_sesion.png", "Inicio de sesión", "La autenticación restringe el acceso mediante número de ítem o contrato y contraseña."),
    ("02_pantalla_principal.png", "Pantalla principal", "Menú principal por rol con acceso a las funciones implementadas."),
    ("03_gestion_usuarios.png", "Gestión de usuarios", "Consulta de usuarios, roles, números de ítem y estados."),
    ("04_formulario_nuevo_usuario.png", "Formulario de usuarios", "Registro de cuentas con datos de identificación y asignación de rol."),
    ("05_catalogo_prendas.png", "Catálogo de prendas", "Administración de tipos de prendas utilizados por los procesos del sistema."),
    ("06_catalogo_areas.png", "Catálogo de áreas y alias", "Áreas hospitalarias y alias empleados para la identificación y el OCR."),
    ("07_catalogo_plantillas.png", "Catálogo de plantillas", "Plantillas configuradas para los procesos de Salas y Quirófano."),
    ("08_impresion_plantillas.png", "Generación de plantillas", "Selección y generación de formularios imprimibles en PDF."),
    ("09_dashboard.png", "Dashboard de seguimiento", "Indicadores de alertas, lavado, bajas y prendas en circulación."),
]

for index, (filename, title, desc) in enumerate(evidence, 1):
    story.append(PageBreak())
    story.append(Paragraph(f"4.{index} {title}", styles["H1Black"]))
    story.append(Spacer(1, 0.06 * inch))
    story.append(Paragraph(desc, styles["Body10"]))
    img = Image(str(SHOTS / filename))
    max_w, max_h = 7.0*inch, 4.45*inch
    scale = min(max_w / img.imageWidth, max_h / img.imageHeight)
    img.drawWidth = img.imageWidth * scale
    img.drawHeight = img.imageHeight * scale
    img.hAlign = "CENTER"
    story.append(KeepTogether([img, Paragraph(f"Captura {index}. {title} del sistema SICOTRAZ con datos de prueba.", styles["Caption"])]))

story.append(PageBreak())
story += [
    Paragraph("5 Conclusión del avance", styles["H1Black"]),
    Paragraph(
        "Las actividades realizadas mantienen coherencia con los objetivos del proyecto. El sistema ya demuestra los flujos centrales de digitalización, control y trazabilidad, y la auditoría incrementó su confiabilidad mediante correcciones verificadas por pruebas automatizadas.",
        styles["Body10"],
    ),
    Paragraph(
        "Por lo anterior, se registra un avance global del 85 %. El trabajo pendiente está delimitado y no se presenta como terminado: corresponde principalmente a validación operativa institucional, despliegue y mejoras posteriores a la prueba de campo.",
        styles["Body10"],
    ),
]

doc.build(story)
print(OUT)
