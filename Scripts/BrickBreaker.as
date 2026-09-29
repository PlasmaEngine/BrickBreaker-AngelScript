#include "BrickBreakerSimulation.as"
#include "Tests/BrickBreakerChecks.as"

class BrickBreaker : plAngelScriptClass
{
  bool RunMechanicsChecks = false;

  private BrickBreakerSimulation m_Game;
  private double m_Accumulator = 0;
  private plGameObjectHandle m_Paddle;
  private plGameObjectHandle m_Ball;
  private array<plGameObjectHandle> m_Bricks(24);

  void OnSimulationStarted()
  {
    if (RunMechanicsChecks)
    {
      BrickBreakerChecks checks;
      if (!checks.Run())
        throw("Brick Breaker mechanics checks failed.");

      plStringBuilder result;
      result.SetFormat("Brick Breaker: {} mechanics checks passed.", checks.Checks);
      plLog::Info(result.GetView());
    }

    m_Game.Reset();
    m_Accumulator = 0;

    m_Paddle = GetOwner().FindChildByName("Paddle", false).GetHandle();
    m_Ball = GetOwner().FindChildByName("Ball", false).GetHandle();
    for (int i = 0; i < 24; ++i)
    {
      plStringBuilder name;
      name.SetFormat("Brick {}", i + 1);
      m_Bricks[i] = GetOwner().FindChildByName(plTempHashedString(name.GetView()), false).GetHandle();
    }

    SetUpdateInterval(plTime::MakeZero());
    UpdatePresentation();
  }

  void Update()
  {
    plInputComponent@ inputComponent;
    if (!GetOwner().TryGetComponentOfBaseType(@inputComponent))
      return;

    // The camera faces down the table, so positive world X is screen-left.
    float input = inputComponent.GetCurrentInputState("Left", false) - inputComponent.GetCurrentInputState("Right", false);
    if (inputComponent.GetCurrentInputState("Restart", true) > 0)
    {
      m_Game.Reset();
      m_Accumulator = 0;
    }

    if (inputComponent.GetCurrentInputState("Pause", true) > 0)
    {
      m_Game.Paused = !m_Game.Paused;
      m_Accumulator = 0;
    }

    if (inputComponent.GetCurrentInputState("Launch", true) > 0)
      m_Game.Launch();

    // Cap catch-up after a stall, preserving the same 120 Hz rules as C++.
    if (!m_Game.Paused)
    {
      m_Accumulator += plMath::Min(GetWorld().GetClock().GetTimeDiff().GetSeconds(), 0.1);
      while (m_Accumulator >= m_Game.FixedStep)
      {
        m_Game.Step(input);
        m_Accumulator -= m_Game.FixedStep;
      }
    }

    UpdatePresentation();
  }

  private void UpdatePresentation()
  {
    plGameObject@ object;
    if (GetWorld().TryGetObject(m_Paddle, @object))
      object.SetLocalPosition(plVec3(m_Game.PaddleX, m_Game.PaddleY, 0.34f));

    if (GetWorld().TryGetObject(m_Ball, @object))
      object.SetLocalPosition(plVec3(m_Game.BallX, m_Game.BallY, 0.38f));

    for (int i = 0; i < 24; ++i)
      if (GetWorld().TryGetObject(m_Bricks[i], @object))
        object.SetActiveFlag(m_Game.Bricks[i]);

    plLocalBlackboardComponent@ hud;
    if (!GetOwner().TryGetComponentOfBaseType(@hud))
      return;

    hud.SetEntryValue("Score", m_Game.Score);
    hud.SetEntryValue("Lives", m_Game.Lives);
    hud.SetEntryValue("Bricks", m_Game.RemainingBricks());

    plString title;
    plString subtitle;
    if (m_Game.Paused)
    {
      title = "PAUSED";
      subtitle = "P or ESC to resume";
    }
    else if (m_Game.State == RoundState::Ready)
    {
      title = m_Game.Lives == 3 ? "CLEAR THE TABLE" : "TRY ANOTHER BALL";
      subtitle = "Move into position, then press SPACE to launch";
    }
    else if (m_Game.State == RoundState::Won)
    {
      title = "TABLE CLEARED";
      subtitle = "24 bricks. Nicely done. Press R to play again.";
    }
    else if (m_Game.State == RoundState::Lost)
    {
      title = "OUT OF BALLS";
      subtitle = "Press R for a fresh table";
    }

    hud.SetEntryValue("ShowPrompt", !title.IsEmpty());
    hud.SetEntryValue("PromptTitle", title);
    hud.SetEntryValue("PromptSubtitle", subtitle);
  }
}
