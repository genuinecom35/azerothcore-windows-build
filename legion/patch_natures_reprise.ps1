# Apply a narrow quest 13946 spell hook to the pinned LegionCore build.
# Source: Nature's Reprisal (13946), Ireroot Seeds (46716), Nature's Fury (65455).
$ErrorActionPreference = 'Stop'
$Source = Join-Path $env:GITHUB_WORKSPACE 'legion-src/src/server/scripts/Spells/spell_quest.cpp'
$Sql = Join-Path $env:GITHUB_WORKSPACE 'legion-src/sql/updates/world/2026_10_30_01_natures_reprise.sql'
if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { throw "Missing spell_quest.cpp: $Source" }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $Sql) -PathType Container)) { throw 'Missing world SQL update directory' }

$Cpp = [IO.File]::ReadAllText($Source)
$ClassName = 'spell_q13946_natures_reprise'
if ($Cpp.Contains('class ' + $ClassName)) { throw 'Nature Reprisal quest spell script already exists upstream: review before patching.' }

$ClassAnchor = 'void AddSC_quest_spell_scripts()'
$RegistrationAnchor = '    new spell_q55_sacred_cleansing();'
if ($Cpp.Split([string[]]@($ClassAnchor), [System.StringSplitOptions]::None).Length -ne 2) { throw 'Quest spell script registration anchor has changed' }
if ($Cpp.Split([string[]]@($RegistrationAnchor), [System.StringSplitOptions]::None).Length -ne 2) { throw 'Quest spell script registration list has changed' }

$Class = @'
// Quest 13946 - Nature's Reprisal. Ireroot Seeds (46716) cast Nature's Fury (65455).
// The item must grant one objective credit per living Fel Rock grellkin hit.
// The objective entry is loaded from the current quest template, avoiding
// hard-coded kill-credit entries that can differ between database versions.
class spell_q13946_natures_reprise : public SpellScriptLoader
{
public:
    spell_q13946_natures_reprise() : SpellScriptLoader("spell_q13946_natures_reprise") { }

    class spell_q13946_natures_reprise_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_q13946_natures_reprise_SpellScript);

        void HandleHit()
        {
            Player* player = GetCaster()->ToPlayer();
            Creature* target = GetHitCreature();
            if (!player || !target || !target->IsAlive() ||
                player->GetQuestStatus(13946) != QUEST_STATUS_INCOMPLETE)
                return;

            switch (target->GetEntry())
            {
                case 2002: // Rascal Sprite
                case 2003: // Shadow Sprite
                case 2004: // Dark Sprite
                case 2005: // Vicious Grell
                    break;
                default:
                    return;
            }

            Quest const* quest = sQuestDataStore->GetQuestTemplate(13946);
            if (!quest)
                return;

            for (QuestObjective const& objective : quest->GetObjectives())
            {
                if (objective.Type != QUEST_OBJECTIVE_MONSTER ||
                    objective.Amount != 12 || objective.ObjectID <= 0)
                    continue;

                player->QuestObjectiveSatisfy(uint32(objective.ObjectID), 1,
                    QUEST_OBJECTIVE_MONSTER, target->GetGUID());

                // Nature's Fury should destroy the grellkin, not merely stun it.
                // Self-kill prevents a second ordinary kill-credit being granted.
                target->Kill(target);
                break;
            }
        }

        void Register() override
        {
            AfterHit += SpellHitFn(spell_q13946_natures_reprise_SpellScript::HandleHit);
        }
    };

    SpellScript* GetSpellScript() const override
    {
        return new spell_q13946_natures_reprise_SpellScript();
    }
};

'@
$Cpp = $Cpp.Replace($ClassAnchor, $Class + [Environment]::NewLine + $ClassAnchor)
$Cpp = $Cpp.Replace($RegistrationAnchor, $RegistrationAnchor + [Environment]::NewLine + '    new spell_q13946_natures_reprise();')
if (-not ($Cpp.Contains('new spell_q13946_natures_reprise();') -and
          $Cpp.Contains('AfterHit += SpellHitFn(spell_q13946_natures_reprise_SpellScript::HandleHit);'))) {
    throw 'Nature Reprisal quest spell insertion failed'
}
[IO.File]::WriteAllText($Source, $Cpp, [Text.UTF8Encoding]::new($false))

$SqlText = @'
-- Teldrassil: Nature's Reprisal (13946). Ireroot Seeds (46716) -> Nature's Fury (65455).
-- Ensure a successful item hit counts toward the 12 grellkin objective.
DELETE FROM spell_script_names WHERE spell_id = 65455 AND ScriptName = 'spell_q13946_natures_reprise';
INSERT INTO spell_script_names (spell_id, ScriptName) VALUES (65455, 'spell_q13946_natures_reprise');
'@
[IO.File]::WriteAllText($Sql, $SqlText, [Text.UTF8Encoding]::new($false))
Write-Host 'Registered Nature Reprisal quest spell hook and SQL binding.'
