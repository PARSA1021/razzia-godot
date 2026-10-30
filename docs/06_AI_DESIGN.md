# Razzia Mobile — AI Design

## 1. Goal

Create AI opponents that make believable decisions while remaining deterministic and debuggable.

The first AI should be rule-based.

Do not use machine learning for MVP.

---

# 2. AI Architecture

```text
AIController
├── CardSelector
├── BarEvaluator
├── RiskEvaluator
├── NegotiationAI
├── DuelDecisionAI
└── PersonalityProfile
```

---

# 3. AI Difficulty

## EASY

Purpose:

- beginner-friendly;
- slightly imperfect;
- fast to implement.

Behavior:

- prioritize high-value bars;
- sometimes choose a lower-value bar;
- use simple card strength;
- accept reasonable offers;
- make occasional non-optimal proposals.

Avoid completely random behavior.

---

## NORMAL

Consider:

- bar money;
- card die symbol;
- Zocker/Razzia type;
- number of known competing cards;
- current player money;
- opponent money;
- round number;
- probability of competition.

---

## HARD

Additionally consider:

- discarded cards;
- remaining deck information;
- observed player behavior;
- expected opponent choices;
- expected duel value;
- end-game pressure;
- opportunity cost of spending a strong card.

---

# 4. Card Selection Model

For each playable card, calculate:

```text
cardValue =
    prizeValue
  × expectedSuccessProbability
  + negotiationValue
  + duelValue
  + endGameValue
  - competitionRisk
```

This is a heuristic, not a machine-learning model.

---

# 5. Bar Value

Base value:

```ts
barValue = bar.money;
```

Add a persistence bonus if money has accumulated for multiple rounds.

Example:

```text
$10k = low
$30k = medium
$70k = high
$100k+ = very high
```

Do not hard-code these labels into the rules engine; they are AI heuristics.

---

# 6. Zocker Evaluation

A Zocker card is attractive when:

- the bar contains significant money;
- competition is expected to be low;
- the card has a high die symbol;
- the AI has a strong negotiation position.

Example heuristic:

```text
score =
  barMoney * 1.0
  + dieSymbol * 3000
  - estimatedCompetition * 10000
```

The exact weights should live in AI configuration, not scattered throughout code.

---

# 7. Razzia Evaluation

Razzia becomes valuable when:

- the bar has a lot of money;
- at least one opponent is likely to play a Zocker card there;
- the AI has a strong Razzia die symbol;
- the AI expects to have a favorable negotiation position.

Do not treat Razzia as automatically valuable.

If nobody is likely to play a Zocker card, a Razzia card may simply leave the money untouched.

---

# 8. Opponent Modeling

Track non-secret historical information only.

Examples:

```ts
interface OpponentProfile {
  playerId: PlayerId;

  barSelectionFrequency: Record<BarId, number>;

  zockerFrequency: number;

  razziaFrequency: number;

  averageDieSymbol: number;

  recentChoices: BarId[];
}
```

The AI should not have access to hidden information that a real player would not have.

---

# 9. Information Rules

AI may know:

- its own hand;
- revealed cards;
- discarded cards;
- current bar money;
- public player money;
- historical public actions.

AI may not know before reveal:

- human player's selected card;
- another AI's selected card;
- another player's private reasoning.

If the AI can access hidden selections internally, that information must not influence its decision.

---

# 10. Negotiation AI

The AI must decide:

### As proposer

How much to offer each opponent.

Factors:

- prize size;
- opponent's duel strength;
- AI's duel strength;
- opponent's current money;
- whether the opponent is likely to accept;
- remaining rounds.

Example:

```text
offer =
    minimumAcceptableAmount
  + riskPremium
```

---

# 11. Accept vs Duel

When responding to a proposal:

```text
acceptValue = offeredMoney

duelValue =
    expectedDuelWinProbability
    × prizeRemaining
```

Accept when the expected value of acceptance is sufficiently competitive with the expected duel value.

The threshold should be configurable by difficulty/personality.

---

# 12. AI Personalities

Optional profiles:

### Conservative

- accepts fair offers;
- avoids risky duels;
- prefers smaller guaranteed gains.

### Aggressive

- challenges more often;
- prefers high-value bars;
- accepts fewer offers.

### Opportunist

- targets neglected bars;
- prefers low competition;
- uses Razzia when opponents appear predictable.

These personalities modify weights, not rules.

---

# 13. AI Proposal Examples

For a $55,000 prize with two claimants:

```text
AI has ★5
Opponent has ★3

Possible proposals:

AI $40k / Opponent $15k
AI $35k / Opponent $20k
AI $30k / Opponent $25k
```

AI evaluates acceptance probability.

The rules engine validates the final proposal.

The AI must never be allowed to submit an invalid proposal.

---

# 14. AI Duel Logic

The AI cannot know the future die roll.

It can know:

```text
myCardSymbol
opponentCardSymbol
```

Expected score:

```text
expectedScore = dieSymbol + 3.5
```

because a six-sided die has an expected value of 3.5.

Win probability can be computed exactly for two players:

```text
P(mySymbol + rollA > opponentSymbol + rollB)
+
tieProbability × tieBreakRule
```

The tie-break rule is important because the challenger wins ties.

---

# 15. AI Testing

Every AI decision should be testable without the UI.

Example:

```ts
const choice = ai.chooseCard(gameState);
expect(choice).toBeDefined();
expect(player.hand).toContain(choice);
```

Negotiation:

```ts
const proposal = ai.makeProposal(state);
expect(isValidProposal(proposal)).toBe(true);
```

Duel:

```ts
const decision = ai.shouldChallenge(state);
expect(typeof decision).toBe("boolean");
```

---

# 16. AI Anti-Cheat Test

Create a test where:

- human selects a hidden card;
- AI makes its decision;
- hidden human selection is changed;
- all public information remains the same.

The AI's decision should remain unchanged.

This confirms that the AI is not accidentally reading hidden state.

---

# 17. Future AI

Only after the rule-based AI is stable consider:

- Monte Carlo simulation;
- self-play;
- reinforcement learning.

Any advanced AI must still obey the same information boundaries.
