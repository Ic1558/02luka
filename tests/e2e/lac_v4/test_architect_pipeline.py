from __future__ import annotations

from textwrap import dedent

import pytest

from agents.ai_manager.requirement_parser import parse_requirement_md
from agents.architect.architect_agent import ArchitectAgent
from agents.architect.spec_builder import ArchitectSpec, SpecBuilder


@pytest.mark.slow
def test_architect_pipeline_produces_spec_from_requirement():
    """
    Minimal E2E smoke test:

    Requirement.md (content) -> parse_requirement_md()
                              -> ArchitectAgent.design()
                              -> SpecBuilder.build_spec()
    """
    requirement_md = dedent(
        """
        # Requirement: User Authentication System
        **ID:** REQ-20251129-01
        **Priority:** P1
        **Complexity:** Moderate

        ## Objective
        Implement a secure user authentication system with JWT tokens.

        ## Acceptance Criteria
        - [ ] User can login and receive JWT token
        - [ ] Protected endpoints verify JWT
        """
    ).strip()

    parsed = parse_requirement_md(requirement_md)
    architect = ArchitectAgent()
    spec_builder = SpecBuilder()

    analysis = architect.design(parsed)
    spec = spec_builder.build_spec(analysis)

    assert isinstance(spec, ArchitectSpec)
    assert spec.requirement_id.startswith("REQ-")
    assert isinstance(spec.structure, dict)
    assert isinstance(spec.patterns, list)
    assert isinstance(spec.standards, dict)
    assert isinstance(spec.qa_checklist, list)
