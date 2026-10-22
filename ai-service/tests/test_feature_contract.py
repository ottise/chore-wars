import numpy as np
import pytest
from app.features import DictFeatureEncoder
from app.ml import candidates, make_estimator, select_threshold
from app.schemas import AvailabilityCandidate


def test_identity_cannot_become_a_learning_feature():
    for key in ("member_id", "user_id", "house_id", "episode_id", "occurrence_id"):
        with pytest.raises(ValueError, match="Identity"):
            DictFeatureEncoder().fit([{key: "private-id", "karma": 5}])


def test_ordinal_vocabulary_is_fit_only_and_missing_is_distinct():
    encoder = DictFeatureEncoder(encoding="ordinal").fit(
        [{"work": "known", "karma": 1}, {"work": None, "karma": None}]
    )
    known, unknown, missing = encoder.transform(
        [
            {"work": "known", "karma": 2},
            {"work": "future-type", "karma": 2},
            {"work": None, "karma": 2},
        ]
    )
    assert known[-1] >= 0 and unknown[-1] == -1 and missing[-1] == -2
    assert "future-type" not in str(encoder.manifest())
    assert np.isfinite([known, unknown, missing]).all()


@pytest.mark.parametrize("family,config", candidates())
def test_candidate_handles_unseen_work_type_and_missing_numerics(family, config):
    rows = [
        {
            "template_id": f"work-{i % 3}",
            "karma": None if i % 7 == 0 else i % 8,
            "difficulty": "EASY",
        }
        for i in range(60)
    ]
    model = make_estimator(family, config).fit(rows, [i % 2 for i in range(60)])
    probability = model.predict_proba(
        [{"template_id": "new", "karma": None, "difficulty": "HARD"}]
    )
    assert probability.shape == (1, 2) and np.isfinite(probability).all()
    assert probability.sum() == pytest.approx(1)


def test_ambiguous_availability_stays_incomplete_and_invalid_interval_rejected():
    assert AvailabilityCandidate(kind="BUSY").local_date is None
    with pytest.raises(ValueError):
        AvailabilityCandidate(kind="BUSY", start_minute=600, end_minute=500)
    assert select_threshold([0, 0], [0.1, 0.2]) is None
