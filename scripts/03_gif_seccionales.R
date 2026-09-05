# Genera el GIF de la portada: las 280 seccionales cambiando de delito.
#
# El remate es el abigeato, que da vuelta el mapa: el 81% de las rapinas del
# pais son de Montevideo, y del abigeato apenas el 1,6%.
#
# Entradas : data/app/seccionales.rds, data/app/eventos.parquet
# Salida   : docs/img/seccionales.gif   (requiere ImageMagick para el ensamblado)

suppressPackageStartupMessages({
  library(sf); library(dplyr); library(arrow); library(data.table)
})

OUT <- "docs/img"
TMP <- file.path(tempdir(), "frames_seccionales")
dir.create(TMP, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

geo <- readRDS("data/app/seccionales.rds") |> st_transform(32721)
ev  <- as.data.table(read_parquet("data/app/eventos.parquet"))
ev  <- ev[!is.na(sec_id)]

BG <- "#0B1220"; FG <- "#EAF0F8"; MUTED <- "#93A6C2"; FAINT <- "#42566F"
PAL <- c("#FFFFCC", "#FFE9A3", "#FED976", "#FEB24C", "#FD8D3C",
         "#FC4E2A", "#E31A1C", "#B10026")

VISTAS <- list(
  list(key = NULL,                  titulo = "Los cinco delitos juntos",
       nota = "Montevideo y la costa concentran casi todo"),
  list(key = "HURTO",               titulo = "Hurto",
       nota = "1,5 millones de denuncias: manda el peso de la población"),
  list(key = "RAPIÑA",              titulo = "Rapiña",
       nota = "Todavía más concentrado: el área metropolitana"),
  list(key = "VIOLENCIA DOMÉSTICA", titulo = "Violencia doméstica",
       nota = "Sigue la población, pero se reparte más"),
  list(key = "ABIGEATO",            titulo = "Abigeato",
       nota = "Se da vuelta el mapa: el delito del campo")
)

bbox <- st_bbox(geo)
asp  <- diff(bbox[c(1, 3)]) / diff(bbox[c(2, 4)])

png_frame <- function(v, archivo) {
  d <- if (is.null(v$key)) ev else ev[delito == v$key]
  cnt <- d[, .(n = .N), by = .(sec_id = as.character(sec_id))]
  g <- merge(geo, cnt, by = "sec_id", all.x = TRUE)
  g$n[is.na(g$n)] <- 0

  cortes <- unique(quantile(g$n, probs = seq(0, 1, length.out = 9), na.rm = TRUE))
  idx <- if (length(cortes) > 2) {
    as.integer(cut(g$n, breaks = cortes, include.lowest = TRUE))
  } else {
    rep(1L, nrow(g))
  }
  cols <- PAL[pmin(pmax(idx, 1), length(PAL))]

  png(archivo, width = 1080, height = 1350, res = 110)
  op <- par(bg = BG, mar = c(0, 0, 0, 0), xpd = NA)
  plot.new(); plot.window(xlim = c(0, 1080), ylim = c(1350, 0))
  rect(-10, -10, 1090, 1360, col = BG, border = NA)

  # --- encabezado ---
  text(70, 88,  "Denuncias por seccional policial", col = FG, cex = 2.35,
       font = 2, adj = 0)
  text(70, 132, "Uruguay · 2013–2026 · 280 seccionales · 2,5 M de denuncias",
       col = MUTED, cex = 1.28, adj = 0)

  # El titulo mas largo roza el numero de la derecha: se achica solo.
  cex_tit <- if (nchar(v$titulo) > 20) 2.45 else 3.1
  text(70, 232, v$titulo, col = FG, cex = cex_tit, font = 2, adj = 0)
  text(70, 278, v$nota,   col = MUTED, cex = 1.35, adj = 0)

  total <- sum(g$n)
  text(1010, 232, format(total, big.mark = "."), col = FG, cex = 2.0,
       font = 2, adj = 1)
  text(1010, 268, "denuncias", col = FAINT, cex = 1.2, adj = 1)

  # --- mapa ---
  top <- 330; bot <- 1180
  alto <- bot - top; ancho <- alto * asp
  izq <- (1080 - ancho) / 2

  esc <- function(m) {
    x <- izq + (m[, 1] - bbox[1]) / diff(bbox[c(1, 3)]) * ancho
    y <- top + (bbox[4] - m[, 2]) / diff(bbox[c(2, 4)]) * alto
    cbind(x, y)
  }
  for (i in seq_len(nrow(g))) {
    gm <- st_geometry(g)[[i]]
    polys <- if (inherits(gm, "MULTIPOLYGON")) unlist(gm, recursive = FALSE) else gm
    for (p in polys) {
      m <- if (is.list(p)) p[[1]] else p
      if (!is.matrix(m) || nrow(m) < 3) next
      pt <- esc(m)
      polygon(pt[, 1], pt[, 2], col = cols[i], border = "#0B1220", lwd = 0.35)
    }
  }

  # --- leyenda ---
  lx <- 70; ly <- 1232; w <- 46; h <- 16
  for (k in seq_along(PAL)) {
    rect(lx + (k - 1) * w, ly, lx + k * w, ly + h, col = PAL[k], border = NA)
  }
  text(lx, ly - 12, "menos", col = FAINT, cex = 1.0, adj = 0)
  text(lx + 8 * w, ly - 12, "más", col = FAINT, cex = 1.0, adj = 1)
  text(lx + 8 * w + 18, ly + h - 2, "escala por octiles", col = FAINT,
       cex = 1.0, adj = 0)

  # --- pie ---
  segments(70, 1272, 1010, 1272, col = "#1C2A3E", lwd = 1.2)
  text(70, 1302, "Fuente: Ministerio del Interior (SGSP) · geometría oficial de seccionales",
       col = MUTED, cex = 1.12, adj = 0)
  text(70, 1332, "emilianogonzalez.shinyapps.io/Denuncias", col = "#5E84B8",
       cex = 1.12, adj = 0)
  par(op); dev.off()
}

for (i in seq_along(VISTAS)) {
  f <- sprintf("%s/f%02d.png", TMP, i)
  png_frame(VISTAS[[i]], f)
  cat("cuadro", i, "-", VISTAS[[i]]$titulo, "\n")
}

# El abigeato queda mas tiempo en pantalla: es el remate.
demoras <- c(240, 220, 220, 220, 360)   # centesimas de segundo
cuadros <- sprintf("%s/f%02d.png", TMP, seq_along(VISTAS))
destino <- file.path(OUT, "seccionales.gif")
args <- c("-loop", "0",
          as.vector(rbind(paste0("-delay ", demoras), cuadros)),
          "-layers", "Optimize", destino)
system2("convert", args)
cat("\n", destino, " ", round(file.size(destino) / 1e6, 2), " MB\n", sep = "")
