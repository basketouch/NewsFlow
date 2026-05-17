import Foundation

struct NewsletterHTMLGenerator {

    static func generate(
        hero: NewsletterHero,
        items: [NewsletterItem],
        blocks: [NewsletterBlock] = [],
        edicion: String,
        fecha: String
    ) -> String {
        let edicionLabel  = "Edicion #\(edicion) — \(fecha)"
        let temas         = buildTemas(items: items)
        let indexLinks    = buildIndex(items: items)
        let topBlocks     = blocks.filter { $0.position == .top  }.map { buildBlock($0) }.joined(separator: "\n")
        let bottomBlocks  = blocks.filter { $0.position == .bottom }.map { buildBlock($0) }.joined(separator: "\n")
        let articles      = buildArticles(items: items)

        return """
        <!DOCTYPE html>
        <html lang="es">
        \(head(edicion: edicion, titular: hero.titular))
        <body>

        \(topNav())
        \(bottomNav())

        <div class="page">
          <div id="sec-reader" class="sec on">
            <div class="reader-back">
              <div class="reader-temas">\(temas)</div>
            </div>

            <div class="nl-hero">
              <div class="nl-ey">\(edicionLabel)</div>
              <h1 class="nl-h1">\(escapeHTML(hero.titular))</h1>
              <p class="nl-lead">\(escapeHTML(hero.lead))</p>
            </div>

            <div class="nl-idx">
              <div class="nl-idx-lbl">En esta edicion</div>
              <div class="nl-idx-list">
                \(indexLinks)
              </div>
            </div>

            \(topBlocks)

            \(articles)

            \(bottomBlocks)

            <div class="nl-foot">
              <div class="nl-foot-row">
                <div>
                  <div class="nl-sig">Jorge Lorenzo</div>
                  <div class="nl-sig-sub">Cada semana, lo que importa.</div>
                  <div class="nl-copy">© 2026 Jorge Lorenzo</div>
                </div>
                <div class="nl-flinks">
                  <a href="https://www.linkedin.com/in/jorge-lorenzo-25ba3518/" target="_blank" rel="noopener">LinkedIn</a>
                  <a href="https://x.com/JLbasket" target="_blank" rel="noopener">X</a>
                  <a href="https://www.instagram.com/jorgelorenzo.coach" target="_blank" rel="noopener">Instagram</a>
                  <a href="https://bio.jorgelorenzo.coach/" target="_blank" rel="noopener">Bio</a>
                  <a href="mailto:info@jorgelorenzo.coach">Contacto</a>
                </div>
              </div>
              <div class="nl-legal">
                <a href="https://insidelife.club/documentos-legales/politica-de-privacidad.html" target="_blank">Privacidad</a>
                <a href="https://insidelife.club/documentos-legales/aviso-legal.html" target="_blank">Aviso legal</a>
                <a href="https://insidelife.club/documentos-legales/politica-de-cookies.html" target="_blank">Cookies</a>
                <a href="https://insidelife.club/documentos-legales/terminos-y-condiciones-de-uso.html" target="_blank">Términos</a>
              </div>
            </div>
          </div>
        </div>

        \(subscriptionModal())
        \(javascript())
        </body>
        </html>
        """
    }

    // MARK: - Bloques extra

    private static func buildBlock(_ block: NewsletterBlock) -> String {
        switch block.type {
        case .texto:
            let title = block.textoTitle.isEmpty ? "" :
                "<h2 class=\"art-h2\" style=\"font-family:'Playfair Display',serif;font-size:19px;font-weight:700;line-height:1.22;color:#111;margin-bottom:10px;\">\(escapeHTML(block.textoTitle))</h2>"
            let body = block.textoBody.replacingOccurrences(of: "\n", with: "<br>")
            return """
            <div class="nl-art" style="padding:28px 40px;border-bottom:1px solid #e8e4de;">
              \(title)
              <div class="art-body" style="font-size:13.5px;line-height:1.8;color:#2d2d2d;">\(escapeHTML(body).replacingOccurrences(of: "&lt;br&gt;", with: "<br>"))</div>
            </div>
            """

        case .callout:
            let body = block.calloutBody.replacingOccurrences(of: "\n", with: "<br>")
            return """
            <div style="padding:0 40px;">
              <div class="callout">
                <div class="callout-lbl">\(escapeHTML(block.calloutLabel))</div>
                \(escapeHTML(body).replacingOccurrences(of: "&lt;br&gt;", with: "<br>"))
              </div>
            </div>
            """

        case .promo:
            let btn = block.promoBtn.isEmpty ? "Ver más →" : block.promoBtn
            let link = block.promoLink.isEmpty ? "#" : block.promoLink
            let body = block.promoBody.replacingOccurrences(of: "\n", with: "<br>")
            return """
            <div style="background:#111;padding:28px 40px;">
              <h2 style="font-family:'Playfair Display',serif;font-size:19px;font-weight:700;color:#fff;margin-bottom:10px;">\(escapeHTML(block.promoTitle))</h2>
              <p style="font-size:13.5px;line-height:1.8;color:rgba(255,255,255,.78);">\(escapeHTML(body).replacingOccurrences(of: "&lt;br&gt;", with: "<br>"))</p>
              <a href="\(link)" style="display:inline-block;margin-top:14px;background:#fff;color:#111;font-family:'DM Mono',monospace;font-size:10px;letter-spacing:.12em;text-transform:uppercase;padding:10px 20px;text-decoration:none;">\(escapeHTML(btn))</a>
            </div>
            """

        case .imagen:
            let caption = block.imagenCaption.isEmpty ? "" : """
              <div style="font-family:'DM Mono',monospace;font-size:9px;letter-spacing:.1em;text-transform:uppercase;color:#767676;margin-top:8px;">\(escapeHTML(block.imagenCaption))</div>
            """
            return """
            <div style="padding:20px 40px;">
              <img src="\(block.imagenURL)" style="width:100%;display:block;" alt="\(escapeHTML(block.imagenCaption))"/>
              \(caption)
            </div>
            """

        case .columna:
            guard !block.columnaTexto.isEmpty else { return "" }
            let titulo = block.columnaTitulo.isEmpty ? "Mi columna" : block.columnaTitulo
            let parrafos = block.columnaTexto
                .components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { "<p>\(escapeHTML($0))</p>" }
                .joined(separator: "\n              ")
            return """
            <div class="nl-columna">
              <div class="nl-columna-kicker">Columna</div>
              <h2 class="nl-columna-title">\(escapeHTML(titulo))</h2>
              <div class="nl-columna-body">
                \(parrafos)
              </div>
            </div>
            """
        }
    }

    // MARK: - Temas de la edición (extraídos de las categorías)

    private static func buildTemas(items: [NewsletterItem]) -> String {
        var seen = Set<String>()
        return items
            .compactMap { $0.categoria.components(separatedBy: " · ").first?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .joined(separator: " · ")
    }

    // MARK: - Secciones

    private static func buildIndex(items: [NewsletterItem]) -> String {
        items.enumerated().map { i, item in
            """
            <a class="nl-idx-a" href="#a\(i+1)">\(escapeHTML(item.titulo))</a>
            """
        }.joined(separator: "\n            ")
    }

    private static func buildArticles(items: [NewsletterItem]) -> String {
        // La destacada siempre va primera
        let sorted = items.sorted { $0.destacada && !$1.destacada }
        return sorted.enumerated().map { i, item in
            let n = i + 1
            let cssClass = item.destacada ? "nl-art nl-art-featured" : item.style.cssClass

            // Enlace "Leer en [fuente] →" solo si hay URL real
            let sourceLink: String
            if let url = item.url, !url.isEmpty {
                let label = item.sourceName.isEmpty ? "fuente original" : item.sourceName
                sourceLink = """
                  <div class="art-source-link">
                    <a href="\(url)" target="_blank" rel="noopener" class="art-read-more">Leer en \(escapeHTML(label)) →</a>
                  </div>
                """
            } else {
                sourceLink = ""
            }

            return """
            <div class="\(cssClass)" id="a\(n)">
              <div class="art-hdr">
                <div class="art-n\(item.destacada ? " art-n-featured" : "")">\(n)</div>
                <div>
                  <div class="art-src">\(escapeHTML(item.categoria)) · \(escapeHTML(item.sourceName))</div>
                  <h2 class="art-h2">\(escapeHTML(item.titulo))</h2>
                </div>
              </div>
              <div class="art-body">
                <p>\(escapeHTML(item.textoFinal))</p>
              </div>
              \(sourceLink)
            </div>
            """
        }.joined(separator: "\n            ")
    }

    // MARK: - Head con CSS completo

    private static func head(edicion: String, titular: String) -> String {
        """
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>INSIDE Life - Edicion #\(edicion) - \(escapeHTML(titular))</title>
        <meta name="description" content="\(escapeHTML(titular))">
        <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,700;0,900;1,700&family=DM+Sans:wght@300;400;500&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet">
        <style>
        :root { --white:#ffffff;--off:#f8f6f2;--ink:#111111;--mid:#767676;--rule:#e8e4de;--red:#e8401c; }
        *{box-sizing:border-box;margin:0;padding:0;}
        html{scroll-behavior:smooth;}
        body{font-family:'DM Sans',sans-serif;background:var(--white);color:var(--ink);-webkit-font-smoothing:antialiased;}
        .topnav{position:fixed;top:0;left:0;right:0;z-index:100;height:54px;background:var(--white);border-bottom:1px solid var(--rule);display:flex;align-items:center;justify-content:space-between;padding:0 40px;}
        .nav-brand{display:flex;align-items:center;gap:9px;cursor:pointer;text-decoration:none;}
        .nav-title{font-family:'Playfair Display',serif;font-size:19px;font-weight:900;color:var(--ink);letter-spacing:-.02em;}
        .nav-badge{background:var(--ink);color:var(--white);font-family:'DM Mono',monospace;font-size:8px;letter-spacing:.06em;padding:3px 7px;line-height:1;}
        .nav-links{display:flex;gap:28px;list-style:none;}
        .nav-links button{background:none;border:none;cursor:pointer;padding:0;font-family:'DM Mono',monospace;font-size:10px;letter-spacing:.12em;text-transform:uppercase;color:var(--mid);transition:color .15s;}
        .nav-links button:hover,.nav-links button.active{color:var(--ink);}
        .nav-sub{background:var(--ink);color:var(--white);font-family:'DM Mono',monospace;font-size:9px;letter-spacing:.12em;text-transform:uppercase;padding:8px 16px;border:none;cursor:pointer;transition:background .15s;}
        .nav-sub:hover{background:var(--red);}
        .botnav{display:none;position:fixed;bottom:0;left:0;right:0;z-index:100;height:56px;background:var(--white);border-top:1px solid var(--rule);}
        .botnav button{flex:1;height:100%;border:none;background:none;cursor:pointer;font-family:'DM Mono',monospace;font-size:8.5px;letter-spacing:.09em;text-transform:uppercase;color:var(--mid);border-right:1px solid var(--rule);transition:color .15s;}
        .botnav button:last-child{border-right:none;color:var(--red);}
        .botnav button.active{color:var(--ink);font-weight:500;}
        .page{padding-top:54px;}
        .sec{display:none;min-height:calc(100vh - 54px);}
        .sec.on{display:block;}
        #sec-reader{display:block;padding-top:54px;}
        .reader-back{padding:13px 40px;border-bottom:1px solid var(--rule);display:flex;align-items:center;justify-content:space-between;gap:12px;}
        .back-btn{background:none;border:none;cursor:pointer;font-family:'DM Mono',monospace;font-size:9.5px;letter-spacing:.12em;text-transform:uppercase;color:var(--mid);padding:0;transition:color .15s;}
        .back-btn:hover{color:var(--ink);}
        .reader-temas{font-family:'DM Mono',monospace;font-size:9px;letter-spacing:.08em;text-transform:uppercase;color:var(--red);}
        .nl-hero{background:var(--ink);padding:44px 40px 36px;position:relative;overflow:hidden;}
        .nl-hero::before{content:'';position:absolute;top:-80px;right:-80px;width:260px;height:260px;border-radius:50%;border:50px solid rgba(232,64,28,.1);pointer-events:none;}
        .nl-ey{font-family:'DM Mono',monospace;font-size:9px;letter-spacing:.18em;text-transform:uppercase;color:var(--red);margin-bottom:14px;}
        .nl-h1{font-family:'Playfair Display',serif;font-size:30px;font-weight:900;line-height:1.1;letter-spacing:-.025em;color:#fff;margin-bottom:14px;max-width:520px;}
        .nl-h1 em{font-style:italic;color:#f5a58c;}
        .nl-lead{font-size:13.5px;line-height:1.75;color:rgba(255,255,255,.62);max-width:480px;}
        .nl-idx{background:#fdf0ec;padding:16px 40px;border-bottom:1px solid #f0c7bc;}
        .nl-idx-lbl{font-family:'DM Mono',monospace;font-size:8.5px;letter-spacing:.18em;text-transform:uppercase;color:var(--mid);margin-bottom:8px;}
        .nl-idx-list{display:flex;flex-direction:column;gap:4px;}
        .nl-idx-a{font-size:12px;font-weight:500;color:var(--ink);text-decoration:none;display:flex;align-items:center;gap:7px;transition:color .12s;}
        .nl-idx-a::before{content:'→';font-family:'DM Mono',monospace;color:var(--red);font-size:10px;}
        .nl-idx-a:hover{color:var(--red);}
        .nl-art{padding:28px 40px;border-bottom:1px solid var(--rule);}
        .nl-art-featured{background:#fff8e1;border-left:3px solid #d97706;}
        .nl-art-featured .art-h2{color:#92400e;}
        .nl-art-featured .art-src{color:#b45309;}
        .art-n-featured{background:#d97706 !important;}
        .nl-columna{padding:32px 40px;border-bottom:1px solid var(--rule);background:var(--off);}
        .nl-columna-kicker{font-family:'DM Mono',monospace;font-size:8px;letter-spacing:.18em;text-transform:uppercase;color:var(--mid);margin-bottom:10px;}
        .nl-columna-title{font-family:'Playfair Display',serif;font-size:20px;font-weight:700;font-style:italic;color:var(--ink);margin-bottom:14px;}
        .nl-columna-body{font-size:14px;line-height:1.85;color:#2d2d2d;}
        .nl-columna-sig{margin-top:16px;font-family:'DM Mono',monospace;font-size:9px;letter-spacing:.1em;text-transform:uppercase;color:var(--mid);}
        .art-hdr{display:flex;align-items:flex-start;gap:12px;margin-bottom:14px;}
        .art-n{width:25px;height:25px;background:var(--red);color:#fff;font-family:'DM Mono',monospace;font-size:10px;display:flex;align-items:center;justify-content:center;flex-shrink:0;margin-top:3px;}
        .art-src{font-family:'DM Mono',monospace;font-size:8.5px;letter-spacing:.12em;text-transform:uppercase;color:var(--mid);margin-bottom:4px;}
        .art-h2{font-family:'Playfair Display',serif;font-size:19px;font-weight:700;line-height:1.22;color:var(--ink);}
        .art-body{font-size:13.5px;line-height:1.8;color:#2d2d2d;}
        .art-body p+p{margin-top:9px;}
        .art-source-link{margin-top:14px;}
        .art-read-more{font-family:'DM Mono',monospace;font-size:9.5px;letter-spacing:.1em;text-transform:uppercase;color:var(--red);text-decoration:none;border-bottom:1px solid transparent;transition:border-color .15s;}
        .art-read-more:hover{border-bottom-color:var(--red);}
        .nl-art-dark .art-read-more{color:#f5a58c;}
        .nl-art-blue .art-read-more{color:#f5a58c;}
        .callout{background:var(--off);border-left:3px solid var(--red);padding:11px 14px;margin:15px 0;font-size:12.5px;line-height:1.65;color:#333;}
        .callout-lbl{font-family:'DM Mono',monospace;font-size:8px;letter-spacing:.14em;text-transform:uppercase;color:var(--red);margin-bottom:5px;}
        .nl-art-dark{background:var(--ink);}
        .nl-art-dark .art-h2{color:#fff;}
        .nl-art-dark .art-body{color:rgba(255,255,255,.78);}
        .nl-art-dark .art-src{color:rgba(255,255,255,.38);}
        .nl-art-dark .callout{background:rgba(255,255,255,.06);border-left-color:#f5a58c;color:rgba(255,255,255,.78);}
        .nl-art-dark .callout-lbl{color:#f5a58c;}
        .nl-art-blue{background:#0a1628;}
        .nl-art-blue .art-h2{color:#fff;}
        .nl-art-blue .art-body{color:rgba(255,255,255,.78);}
        .nl-art-blue .art-src{color:rgba(255,255,255,.38);}
        .nl-foot{padding:24px 40px;border-top:1px solid var(--rule);display:flex;flex-direction:column;align-items:stretch;gap:14px;}
        .nl-foot-row{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;}
        .nl-legal{display:flex;flex-wrap:wrap;gap:10px 12px;padding-top:12px;border-top:1px solid var(--rule);}
        .nl-legal a{font-family:'DM Mono',monospace;font-size:8px;letter-spacing:.08em;text-transform:uppercase;color:var(--mid);text-decoration:none;}
        .nl-legal a:hover{color:var(--red);}
        .nl-sig{font-family:'Playfair Display',serif;font-size:14px;font-weight:700;color:var(--ink);}
        .nl-sig-sub{font-size:11px;color:var(--mid);font-style:italic;font-family:'Playfair Display',serif;}
        .nl-copy{font-family:'DM Mono',monospace;font-size:8px;letter-spacing:.06em;color:var(--mid);margin-top:4px;}
        .nl-flinks{display:flex;gap:12px;flex-wrap:wrap;align-items:center;}
        .nl-flinks a{font-family:'DM Mono',monospace;font-size:8.5px;letter-spacing:.1em;text-transform:uppercase;color:var(--mid);text-decoration:none;border-bottom:1px solid var(--rule);transition:color .12s;}
        .nl-flinks a:hover{color:var(--red);}
        .sub-ov{display:none;position:fixed;inset:0;z-index:500;background:rgba(10,10,10,.65);backdrop-filter:blur(3px);align-items:center;justify-content:center;padding:20px;}
        .sub-ov.open{display:flex;}
        .sub-box{background:var(--white);box-shadow:8px 8px 0 var(--ink);padding:36px 32px;max-width:420px;width:100%;position:relative;}
        .sub-close{position:absolute;top:12px;right:14px;background:none;border:none;cursor:pointer;font-size:20px;color:var(--mid);line-height:1;}
        .sub-kicker{font-family:'DM Mono',monospace;font-size:9px;letter-spacing:.1em;color:var(--red);margin-bottom:10px;}
        .sub-h2{font-family:'Playfair Display',serif;font-size:24px;font-weight:900;letter-spacing:-.02em;color:var(--ink);margin-bottom:8px;}
        .sub-desc{font-size:13px;line-height:1.65;color:var(--mid);margin-bottom:22px;}
        .sub-field{margin-bottom:12px;}
        .sub-lbl{display:block;font-family:'DM Mono',monospace;font-size:9px;letter-spacing:.12em;text-transform:uppercase;color:var(--mid);margin-bottom:6px;}
        .sub-in{width:100%;border:1px solid var(--rule);background:var(--off);font-family:'DM Sans',sans-serif;font-size:14px;padding:11px 14px;color:var(--ink);outline:none;}
        .sub-btn{width:100%;margin-top:6px;background:var(--ink);color:var(--white);font-family:'DM Mono',monospace;font-size:10px;letter-spacing:.14em;text-transform:uppercase;padding:14px;border:none;cursor:pointer;}
        .sub-btn:hover{background:var(--red);}
        .botnav-a{flex:1;height:100%;display:flex;align-items:center;justify-content:center;border:none;background:none;cursor:pointer;font-family:'DM Mono',monospace;font-size:8.5px;letter-spacing:.09em;text-transform:uppercase;color:var(--mid);border-right:1px solid var(--rule);text-decoration:none;transition:color .15s;}
        .botnav-a:last-child{border-right:none;}
        @media(max-width:760px){
          .topnav{padding:0 16px;}
          .nav-links{display:none;}
          .nav-sub{display:none;}
          .botnav{display:flex !important;}
          .nl-hero{padding:30px 22px 26px;}
          .nl-idx{padding:14px 22px;}
          .nl-art{padding:24px 22px;}
          .nl-foot{padding:22px;}
          .nl-h1{font-size:24px;}
          .reader-back{padding:12px 22px;}
        }
        </style>
        </head>
        """
    }

    // MARK: - Nav

    private static func bottomNav() -> String {
        """
        <nav class="botnav">
          <a href="https://insidelife.club" class="botnav-a">Inicio</a>
          <a href="https://insidelife.club/archivo" class="botnav-a">Ediciones</a>
          <a href="https://insidelife.club/#sobre" class="botnav-a" style="color:var(--red);">Sobre mí</a>
        </nav>
        """
    }

    private static func topNav() -> String {
        """
        <nav class="topnav">
          <a class="nav-brand" href="https://insidelife.club">
            <div class="nav-title">INSIDE Life</div>
            <div class="nav-badge">By Jorge Lorenzo</div>
          </a>
          <ul class="nav-links">
            <li><a href="https://insidelife.club" style="font-family:'DM Mono',monospace;font-size:10px;letter-spacing:.12em;text-transform:uppercase;color:var(--mid);text-decoration:none;transition:color .15s;">Inicio</a></li>
            <li><a href="https://insidelife.club/archivo" style="font-family:'DM Mono',monospace;font-size:10px;letter-spacing:.12em;text-transform:uppercase;color:var(--mid);text-decoration:none;transition:color .15s;">Ediciones</a></li>
            <li><a href="https://insidelife.club/#sobre" style="font-family:'DM Mono',monospace;font-size:10px;letter-spacing:.12em;text-transform:uppercase;color:var(--mid);text-decoration:none;transition:color .15s;">Sobre mí</a></li>
          </ul>
          <button class="nav-sub" onclick="document.getElementById('sub-modal').classList.add('open')">¿Te la compartieron?</button>
        </nav>
        """
    }

    // MARK: - Modal suscripción

    private static func subscriptionModal() -> String {
        """
        <div class="sub-ov" id="sub-modal">
          <div class="sub-box">
            <button class="sub-close" onclick="document.getElementById('sub-modal').classList.remove('open')">×</button>
            <div class="sub-kicker">¿Alguien te pasó este link?</div>
            <h2 class="sub-h2">Recíbela cada martes</h2>
            <p class="sub-desc">INSIDE Life llega cada semana con lo que importa: IA, liderazgo, deporte y emprendimiento. Sin ruido, sin relleno.</p>
            <div class="sub-field">
              <label class="sub-lbl">Tu email</label>
              <input class="sub-in" type="email" placeholder="tu@email.com">
            </div>
            <button class="sub-btn">Quiero recibirla →</button>
          </div>
        </div>
        """
    }

    // MARK: - JavaScript

    private static func javascript() -> String {
        """
        <script>
        function showSection(id) {
          document.querySelectorAll('.sec').forEach(s => s.classList.remove('on'));
          var el = document.getElementById('sec-' + id);
          if (el) el.classList.add('on');
        }
        </script>
        """
    }

    // MARK: - Util

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
