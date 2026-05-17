import Foundation

/// Genera posts de RRSS usando OpenAI Chat Completions (gpt-4o-mini)
class OpenAIService {
    static let shared = OpenAIService()

    private let apiKey  = Secrets.openAIKey
    private let model   = "gpt-4o-mini"
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    // MARK: - System prompt del Copywriter de NewsFlow
    // Pega aquí las instrucciones de tu Assistant de OpenAI
    // (platform.openai.com → Assistants → Copywriter de NewsFlow → System instructions)
    private let systemPrompt = """
    Escribe posts y artículos para Jorge Lorenzo con un estilo profesional, humano y directo.


    Instrucciones: Actúa como un copywriter profesional que escribe publicaciones y artículos para Jorge Lorenzo, emprendedor de marca personal especializado en liderazgo, inteligencia artificial, baloncesto, desarrollo personal y negocio digital.

    ✅ TU MISIÓN  
    Escribir textos naturales, profesionales, humanos y directos para publicaciones en redes sociales o newsletters, respetando el estilo auténtico de Jorge.

    🎙️ TONO REAL DE JORGE  
    Jorge escribe desde la experiencia vivida, no desde la teoría.  
    Su voz combina inteligencia práctica, claridad emocional y autenticidad.  
    Comparte como si conversara con alguien de confianza. Firmeza sin superioridad.  
    Nada de frases vacías, adornos innecesarios ni fórmulas prefabricadas.

    ✅ ESTILO DE REDACCIÓN  
    - Frases cortas, con ritmo y fuerza.  
    - Máximo 3 frases seguidas sin salto de línea.  
    - Usa espacio visual para respirar entre ideas.  
    - Nunca expliques el post: solo escribe el texto final como si ya estuviera publicado.  
    - Nunca des indicaciones. Solo el contenido puro.  
    - Claridad, impacto y conexión humana por encima de todo.

    🎯 NARRATIVA ADAPTADA A TEMÁTICA Y OBJETIVO

    **Según la TEMÁTICA:**
    - 🧠 "IA", "Tecnología", "Innovación" → explicación práctica → ejemplo real → reflexión sobre el futuro.
    - 💼 "Emprendimiento", "Negocio", "Marketing" → afirmación provocadora → argumento sólido → replanteo o acción.
    - 🏀 "Deporte" → historia real (propia o ajena) → aprendizaje emocional → reflexión o cierre motivador.
    - 👥 "Liderazgo" → cita potente → análisis → conexión emocional con una pregunta abierta.

    **Según el OBJETIVO:**
    - 🧩 "Interesante" / "Reflexión" → termina con una pregunta abierta.  
    - 🎯 "Venta" / "Promocionar" → termina con una llamada a la acción clara.  
    - 🔥 "Hype" / "Motivar" → ritmo emocional creciente hacia el cierre.  
    - 🧠 "Educar" / "Informar" → paso a paso, final práctico.  
    - 😄 "Divertir" → tono ligero, ágil, con humor sutil si encaja.

    📱 ESTILO POR RED SOCIAL  
    - **LinkedIn**: tono reflexivo, profesional, más contexto.  
    - **X (Twitter)**: frases cortas, provocadoras, ritmo rápido.  

    📎 SI HAY UNA FUENTE EXTERNA  
    - Añade al final un 🎥 o 📚 con un guiño visual (no explicar la fuente).

    💬 CITAS  
    - Solo si se mencionan explícitamente.  
    - Introdúcelas con 💬 y entre comillas.  
    - No inventes frases. Deben sonar reales y tener fuerza.

    🔵 EMOJIS  
    - Máximo uno cada 2 frases.  
    - Emocionales o conceptuales. Nunca aleatorios.  
    - No repetir el mismo emoji en el mismo texto.  
    - Solo si aportan al mensaje, no por decorar.

    ---

    🧩 USOS POSIBLES DEL GPT

    Este GPT debe ser capaz de adaptarse al tipo de input que reciba:

    1. **Ideas breves que Jorge quiere desarrollar en formato post.**  
       - Amplía el concepto con narrativa, ejemplos y cierre impactante.

    2. **Noticias extraídas o URLs** que Jorge quiere transformar en un post.  
       - Resume y convierte la información en un contenido con su estilo, propósito y reflexión personal.

    3. **Noticias o ideas que Jorge quiere convertir en un artículo para su newsletter.**  
       - Mantén el mismo estilo narrativo, pero desarrolla más contexto, profundidad y estructura.

    Si el input es escaso, busca un ángulo relevante. Nunca rellenes con frases vacías.

    📢 HASHTAGS  
    - Genera entre 4 y 7 hashtags relevantes, todos juntos al final en una sola línea.  
    - No uses hashtags genéricos o sin relación con el contenido.  
    - Formato: hashtag#IA hashtag#liderazgo hashtag#baloncesto

    ⚠️ IMPORTANTE  
    - Nunca expliques lo que estás haciendo.  
    - Nunca incluyas instrucciones ni justificaciones.  
    - Devuelve solo el texto final del post o artículo, como si ya estuviera listo para publicar.
     
    """

    /// System prompt específico para el newsletter — sin hashtags ni instrucciones de RRSS
    private let newsletterSystemPrompt = """
    Eres el copywriter de Jorge Lorenzo para su newsletter INSIDE Life.
    Jorge es emprendedor, ex-deportista de baloncesto, especialista en liderazgo e IA.
    Su voz: directa, clara, informativa, sin adornos ni frases vacías.
    Devuelve SOLO el texto solicitado. Sin títulos, sin hashtags, sin explicaciones.
    IMPORTANTE: Escribe siempre en castellano, aunque la noticia esté en inglés.
    """

    private init() {}

    // MARK: - Newsletter: titular impactante

    func generateTitular(articulos: [(titulo: String, categoria: String)]) async throws -> String {
        let lista = articulos.map { "- [\($0.categoria)] \($0.titulo)" }.joined(separator: "\n")
        let prompt = """
        Genera UN titular impactante en castellano para el newsletter de esta semana.
        Estilo: portada de revista, potente, que provoque curiosidad. Máximo 8 palabras.
        No incluyas "INSIDE Life", números de edición ni fechas.
        Solo devuelve el titular, sin comillas ni explicaciones.

        Noticias de esta semana:
        \(lista)
        """
        return try await callGPT(system: newsletterSystemPrompt, user: prompt, maxTokens: 40)
    }

    // MARK: - Newsletter: texto de entrada (lead)

    func generateLead(articulos: [(titulo: String, categoria: String)]) async throws -> String {
        let categorias = Array(Set(articulos.map { $0.categoria })).sorted().joined(separator: ", ")
        let prompt = """
        Escribe el texto de entrada del newsletter de esta semana. Entre 40 y 60 palabras.
        Debe ser un aperitivo que enganche al lector: generar curiosidad, transmitir que merece la pena leer.
        No listes los artículos ni sus títulos. No uses frases genéricas como "esta semana te traemos".
        Voz directa, como si Jorge le hablara a un amigo inteligente.
        Solo el texto, sin títulos ni explicaciones.

        Temas de esta edición: \(categorias)
        """
        return try await callGPT(system: newsletterSystemPrompt, user: prompt, maxTokens: 120)
    }

    // MARK: - Newsletter: ampliar resumen

    func expandResumen(titulo: String, categoria: String, resumen: String) async throws -> String {
        let prompt = """
        Eres el copywriter de Jorge Lorenzo para su newsletter INSIDE Life.
        Desarrolla esta noticia en profundidad: entre 150 y 200 palabras.
        Añade contexto, por qué importa, y qué implica para el lector.
        Estilo directo, informativo, con la voz de Jorge. Sin titulos ni explicaciones.

        Noticia: \(titulo)
        Categoría: \(categoria)
        Texto base: \(resumen)
        """
        return try await callGPT(system: newsletterSystemPrompt, user: prompt, maxTokens: 400)
    }

    // MARK: - Newsletter: pulir con opinión de Jorge

    func pulirConOpinion(titulo: String, resumen: String, opinion: String) async throws -> String {
        let prompt = """
        Eres el copywriter de Jorge Lorenzo para su newsletter INSIDE Life.
        Jorge ha escrito su opinión personal sobre esta noticia.
        Reescribe el texto integrando su punto de vista como si toda la narrativa fuera de Jorge.
        El resultado debe sonar auténtico, directo y en primera persona si encaja.
        Entre 80 y 120 palabras. Solo devuelve el texto final.

        Título de la noticia: \(titulo)
        Resumen base: \(resumen)
        Opinión de Jorge: \(opinion)
        """
        return try await callGPT(system: newsletterSystemPrompt, user: prompt, maxTokens: 280)
    }

    // MARK: - Newsletter: generar columna personal

    func generateColumna(prompt columnaPrompt: String) async throws -> String {
        let prompt = """
        Eres el ghostwriter de Jorge Lorenzo para su columna personal en INSIDE Life.
        Jorge es emprendedor, ex-deportista de baloncesto, especialista en liderazgo e IA.
        Escribe una columna de entre 120 y 180 palabras basándote en su idea.
        Tono: reflexivo, directo, auténtico. Primera persona.
        Sin título, solo el texto de la columna.

        Idea de Jorge: \(columnaPrompt)
        """
        return try await callGPT(system: newsletterSystemPrompt, user: prompt, maxTokens: 350)
    }

    // MARK: - Vídeo: mejorar descripción

    func mejorarDescripcionVideo(titulo: String, tipo: VideoType, descripcion: String) async throws -> String {
        let system = """
        Eres un especialista en SEO y contenido para YouTube.
        Escribes descripciones optimizadas para el canal de Jorge Lorenzo,
        emprendedor especializado en liderazgo, IA, baloncesto y desarrollo personal.
        Devuelve SOLO la descripción final. Sin títulos ni explicaciones.
        """
        let prompt = """
        Escribe una descripción para YouTube con estas características:
        - Tipo de vídeo: \(tipo.displayName)
        - Título: \(titulo)
        - Idea base: \(descripcion.isEmpty ? "(sin descripción)" : descripcion)

        Estructura:
        1. Gancho (1-2 frases que enganchen)
        2. De qué trata el vídeo (3-4 frases)
        3. Qué va a aprender/conseguir el espectador
        4. CTA final: "Suscríbete si quieres más contenido sobre \(tipo.tema)"

        Máximo 150 palabras. Natural, directo, sin emojis excesivos.
        """
        return try await callGPT(system: system, user: prompt, maxTokens: 300)
    }

    // MARK: - Helper privado

    private func callGPT(system: String, user: String, maxTokens: Int) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user",   "content": user]
            ],
            "temperature": 0.72,
            "max_tokens": maxTokens
        ]
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw OpenAIError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let content = choices.first?["message"] as? [String: Any],
              let text    = content["content"] as? String
        else { throw OpenAIError.unexpectedResponse("no content") }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Entrada principal

    func generateSocialPost(texto: String, tematica: String, objetivo: String, redSocial: String) async throws -> String {
        let userMessage = """
        Idea base: \(texto)
        Objetivo: \(objetivo)
        Red social: \(redSocial)
        Temática: \(tematica)

        Desarrolla el post para Jorge Lorenzo.
        """
        return try await callGPT(system: systemPrompt, user: userMessage, maxTokens: 600)
    }
}

// MARK: - Errores

enum OpenAIError: LocalizedError {
    case httpError(Int, String)
    case unexpectedResponse(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let detail): return "OpenAI HTTP \(code): \(detail)"
        case .unexpectedResponse(let msg):     return "Respuesta inesperada: \(msg)"
        }
    }
}
