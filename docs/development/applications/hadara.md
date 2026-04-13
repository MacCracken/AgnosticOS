# Hadara — Culture as Living Entity

> **Hadara** (Arabic: حضارة — civilization, culture, the refined way of settled life. From the root for "presence" — culture as *being present in a place*.)

| Field | Value |
|-------|-------|
| Status | Scaffolded (0.1.0) |
| Priority | 3 — cultural infrastructure for bhava, joshua, natya, time-machine, jnana |
| Crate | `hadara` |
| Repository | `MacCracken/hadara` |
| Runtime | library crate |
| Domain | Cultural modeling — cultures as first-class entities with practices, values, art forms, lineage, evolution, and relationship to other cultures |

---

## Why First-Party

No crate in the ecosystem models **Culture as a first-class entity**. Adjacent crates touch culture from different angles — itihas captures events, sangha captures social structures, avatara captures archetypes, varna captures languages, natya captures narrative traditions — but the living cultural fabric that connects all of them has no primary owner.

The AGNOS stack needs cultural data in at least six contexts:

- **bhava** needs cultural display rules (emotional expression varies by culture — Japanese restraint vs Italian expressiveness vs hip-hop directness)
- **avatara** needs to know which culture's archetypes to overlay (Thoth is Egyptian, Hermes is Greek, Nabu is Babylonian — same function, different cultural expression)
- **joshua** needs culturally authentic NPC behavior (a tavern keeper in medieval Japan vs Renaissance Italy vs 1970s Bronx)
- **natya** needs cultural context for narrative structures (rasa theory is Indian, three-act structure is Western, kishōtenketsu is Japanese)
- **The time-machine vision** needs cultural data to render a place at a time (Rome in 44 BCE requires Roman culture, not just coordinates and buildings)
- **jnana** needs to serve culturally-contextualized answers when the query demands it

Without hadara, each consumer invents its own cultural data structures, duplicates effort, and risks inconsistency. Hadara consolidates cultural modeling the way itihas consolidates historical events and sangha consolidates social structures.

## Design Principles

1. **Culture as entity, not attribute.** A culture is not a tag on an event or a modifier on a person. It is a first-class thing with identity, lifecycle, practices, values, art, lineage, and relationships to other cultures.
2. **Living and historical.** Hadara models cultures that are active today (hip-hop, Persian diaspora, Scottish Highland revival) alongside cultures that are historical (ancient Egyptian, classical Greek, Mesopotamian). The `status` field captures where each culture sits on the spectrum: active → dormant → revived → historical → extinct.
3. **Relational.** Cultures don't exist in isolation. They influence each other, syncretize, conflict, exchange, and branch. Hadara models these relationships as first-class connections between culture entities.
4. **Layered detail.** A culture can be described at overview level (name, region, era, core values) or in deep detail (specific rituals, lineage chains, sacred texts, material culture). Consumers request the depth they need.
5. **Consumer-driven, not encyclopedic.** Hadara is not trying to contain all human cultural knowledge. It models the *structure* of cultural entities so that consumers (bhava, joshua, natya, jnana) can query and reason about cultures consistently. Content depth grows as consumers demand it.

## Core Types

### Culture

The primary entity. Everything else hangs off this.

```
Culture {
    id: CultureId,
    name: String,                    // "Hip-Hop", "Persian", "Scottish Highland"
    endonym: Option<String>,         // self-designation in own language
    etymology: Option<String>,       // origin of the name
    status: CultureStatus,           // Active, Dormant, Revived, Historical, Extinct
    geographic_roots: Vec<Region>,   // where it emerged
    diaspora: Vec<Region>,           // where it spread
    time_span: TimeSpan,             // emergence → periods → current
    parent_cultures: Vec<CultureId>, // what it grew from
    child_cultures: Vec<CultureId>,  // what grew from it
    core_values: Vec<Value>,         // what the culture teaches/believes
    practices: Vec<Practice>,        // rituals, daily practices, ceremonies
    art_forms: Vec<ArtForm>,         // music, dance, visual art, literature, oral tradition
    key_figures: Vec<Figure>,        // founders, teachers, transformative figures
    sacred_texts: Vec<Text>,         // canonical/foundational works
    material_culture: Vec<Artifact>, // clothing, architecture, food, tools
    subcultures: Vec<CultureId>,     // movements within the culture
    languages: Vec<LanguageId>,      // associated languages/dialects (links to varna)
    relationships: Vec<CultureRelation>, // influence, syncretism, exchange, conflict
}
```

### CultureStatus

```
enum CultureStatus {
    Active,      // living, practiced today (hip-hop, Persian, Japanese)
    Dormant,     // not actively practiced but not lost (some indigenous traditions)
    Revived,     // was dormant, now being actively restored (Scottish Gaelic, Hawaiian)
    Historical,  // well-documented but no living practitioners in original form (classical Roman)
    Extinct,     // lost, minimal documentation (some pre-Columbian cultures)
}
```

### CultureRelation

```
struct CultureRelation {
    source: CultureId,
    target: CultureId,
    relation_type: RelationType,  // Influenced, SyncretizedWith, BranchedFrom, ConflictedWith, Exchanged
    period: Option<TimeSpan>,     // when the relationship was active
    description: Option<String>,  // what was exchanged/influenced
}
```

### Practice

```
struct Practice {
    name: String,
    category: PracticeCategory,  // Ritual, DailyPractice, Ceremony, Festival, ArtPractice, MartialPractice
    description: String,
    frequency: Option<Frequency>, // Daily, Weekly, Seasonal, Annual, Lifecycle, Spontaneous
    sacred: bool,                 // whether the practice has spiritual/religious significance
}
```

### ArtForm

```
struct ArtForm {
    name: String,
    medium: ArtMedium,  // Music, Dance, VisualArt, Literature, OralTradition, Theater, Architecture, Textile, Culinary
    description: String,
    key_works: Vec<String>,    // notable examples
    key_figures: Vec<Figure>,  // masters of this form within the culture
}
```

## Example: Hip-Hop Culture

```rust
Culture {
    name: "Hip-Hop",
    endonym: Some("Hip Hop Kulture"),  // Temple of Hiphop designation
    etymology: Some("Disputed — possibly from DJ Hollywood's rhythmic phrasing"),
    status: CultureStatus::Active,
    geographic_roots: vec![Region::new("Bronx, New York City", 1973)],
    diaspora: vec![
        Region::new("Los Angeles", 1980),
        Region::new("Atlanta", 1990),
        Region::new("London", 1982),
        Region::new("Paris", 1984),
        Region::new("Tokyo", 1985),
        Region::new("Seoul", 1990),
    ],
    time_span: TimeSpan::from(1973, None),  // ongoing
    core_values: vec![
        Value::new("Self-expression", "Individual voice through artistic practice"),
        Value::new("Community", "The cypher, the block party, the crew"),
        Value::new("Knowledge of self", "Temple of Hiphop: hip-hop as consciousness"),
        Value::new("Sovereignty", "Independence from label/corporate control"),
        Value::new("Innovation", "Taking existing technology and repurposing it — turntablism, sampling, beatboxing"),
    ],
    practices: vec![
        Practice::new("Cypher", PracticeCategory::ArtPractice, "Circular freestyle session — MC or dance"),
        Practice::new("Battle", PracticeCategory::ArtPractice, "Competitive display of skill — MC, DJ, dance, graffiti"),
        Practice::new("Block party", PracticeCategory::Festival, "Community gathering with DJ, MC, dance — the original context"),
    ],
    art_forms: vec![
        ArtForm::new("MCing", ArtMedium::Music, "Rhythmic vocal delivery over beats"),
        ArtForm::new("DJing", ArtMedium::Music, "Turntablism, beat matching, scratching"),
        ArtForm::new("Breaking", ArtMedium::Dance, "Athletic floor-based dance — the original physical expression"),
        ArtForm::new("Graffiti/Aerosol Art", ArtMedium::VisualArt, "Large-scale public visual art"),
        ArtForm::new("Beatboxing", ArtMedium::Music, "Vocal percussion — the human drum machine"),
        ArtForm::new("Knowledge", ArtMedium::OralTradition, "The ninth element (Temple of Hiphop) — conscious transmission"),
    ],
    key_figures: vec![
        Figure::new("DJ Kool Herc", "Originated the breakbeat, the foundational DJ technique"),
        Figure::new("Afrika Bambaataa", "Founded Universal Zulu Nation, codified the elements"),
        Figure::new("Grandmaster Flash", "Pioneered turntablism techniques"),
        Figure::new("KRS-One", "Founded Temple of Hiphop, authored The Gospel of Hip Hop, expanded to nine elements"),
    ],
    sacred_texts: vec![
        Text::new("The Gospel of Hip Hop", "KRS-One", 2009, "The foundational text of Temple of Hiphop"),
    ],
    // ...
}
```

## Relationship to Other Crates

| Crate | Relationship |
|-------|-------------|
| **itihas** | itihas owns WHEN events happened; hadara owns the cultural CONTEXT they happened within. A war in itihas has a cultural backdrop in hadara. |
| **sangha** | sangha models social STRUCTURES (class, kinship, institutions); hadara models cultural IDENTITY (values, practices, art). A society has structure (sangha) and culture (hadara). |
| **avatara** | avatara provides mythological ARCHETYPES; hadara provides the cultural CONTEXT that produced them. Thoth is an avatara; Egyptian culture is a hadara. |
| **bhava** | bhava CONSUMES cultural display rules from hadara. Emotional expression intensity and style varies by culture. hadara provides the rules; bhava applies them. |
| **varna** | varna models LANGUAGES; hadara links cultures to their languages. A culture's linguistic identity references varna language IDs. |
| **natya** | natya models NARRATIVE STRUCTURES; hadara provides the cultural context that produced them. Rasa theory belongs to Indian culture (hadara); its narrative mechanics belong to natya. |
| **joshua** | joshua needs culturally authentic NPC behavior. hadara provides the cultural data; joshua's NPC system queries it for practices, values, speech patterns. |
| **jnana** | jnana indexes knowledge; hadara provides structured cultural knowledge for the corpus. |
| **kshetra** (planned) | kshetra models (lat, lon, time) → state; hadara adds a cultural layer to that state. "What culture was present at this place and time?" |
| **mabda** | No direct dependency. |

## Roadmap

### Phase 1 — Core Types and Registry

- [ ] Culture, CultureStatus, CultureRelation, Practice, ArtForm, Figure, Text, Artifact types
- [ ] In-memory culture registry with ID-based lookup
- [ ] Seed data: 10-15 cultures spanning ancient through contemporary (Egyptian, Greek, Persian, Roman, Indian/Vedic, Chinese, Japanese, West African, Scottish, Hip-Hop, Aztec/Maya, Aboriginal Australian, Norse)
- [ ] Query by region, time period, status
- [ ] Tests: 80+

### Phase 2 — Relationships and Lineage

- [ ] Culture relationship graph (influence, syncretism, branching, conflict, exchange)
- [ ] Lineage traversal: "what influenced this culture?" / "what did this culture produce?"
- [ ] Syncretism modeling: Hermes Trismegistus as Greek-Egyptian syncretism
- [ ] Temporal relationship queries: "which cultures coexisted in the Mediterranean in 300 BCE?"

### Phase 3 — Consumer Integration

- [ ] bhava integration: cultural display rule presets (export emotion expression modifiers by culture)
- [ ] avatara integration: archetype → culture mapping
- [ ] joshua integration: NPC cultural background queries
- [ ] natya integration: narrative tradition → culture mapping
- [ ] jnana integration: cultural knowledge in the unified corpus

### Phase 4 — Deep Content

- [ ] Expanded seed data: 50+ cultures with detailed practices, art forms, figures, texts
- [ ] Subculture modeling (hip-hop subgenres, Scottish Highland vs Lowland, Shia vs Sunni)
- [ ] Material culture (clothing, architecture, food, tools) with structured attributes
- [ ] Diaspora modeling: how a culture transforms when it moves (Persian → Iranian-American, Scottish → Appalachian)
- [ ] Living culture evolution tracking: key inflection points over time

## Ma'at Mapping

Hadara doesn't map to a single Ma'at confession — it is the **context layer** that gives meaning to many of them. #5 (agriculture → krishi) is a cultural practice. #36 (never raised my voice → dhvani) is a cultural norm. #26 (never shut ears to truth → shabdakosh/jnana/itihas) requires knowing which culture's truth-telling traditions to listen to. Hadara provides the cultural ground that the other crates stand on.

---

*Last Updated: 2026-04-12*
