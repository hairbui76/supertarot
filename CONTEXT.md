# SuperTarot Context

SuperTarot is a tarot learning and interpretation assistant. This glossary keeps the domain language precise across crawler data, embedding retrieval, study sessions, and the Telegram bot.

## Language

**Freeform Tarot Question**:
A user message without a slash command or menu selection that asks the bot to interpret tarot meaning using the embedding index. It is not treated as a study answer.
_Avoid_: plain message, normal text, chat text

**Study Answer**:
A learner response to the currently active study draw, submitted with `/answer ...` so it can be graded against retrieved reference chunks.
_Avoid_: freeform answer, normal reply

**Retrieved Reference Chunk**:
A small indexed piece of tarot meaning data returned from the embedding index, carrying card, orientation, facet, keywords, and text.
_Avoid_: search result, document snippet

**Tarot Q&A**:
The bot mode that synthesizes Retrieved Reference Chunks to answer interpretation questions about card meanings, orientations, symbols, elements, astrology, or yes/no correspondences.
_Avoid_: verification, grading, study draw

**Study Draw**:
A generated learning prompt for one user that selects one card and one facet from the 78-card cycle.
_Avoid_: reading, spread, random chat

## Example Dialogue

Developer: "If the user sends `Ace of Cups có hợp cho tình yêu mới không?`, is that a Study Answer?"

Domain expert: "No. That is a Freeform Tarot Question, so the bot should use Tarot Q&A and synthesize Retrieved Reference Chunks about Ace of Cups, love, emotion, and possibly water."

Developer: "How does the user submit an answer for grading after `/random`?"

Domain expert: "They must send `/answer ...`. That text is a Study Answer and belongs to verification, not Tarot Q&A."
