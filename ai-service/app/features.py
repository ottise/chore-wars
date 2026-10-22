from collections import Counter

import numpy as np
from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, OrdinalEncoder, StandardScaler


class DictFeatureEncoder(TransformerMixin, BaseEstimator):
    def __init__(self, encoding="onehot", scale=False):
        self.encoding = encoding
        self.scale = scale

    def fit(self, rows, y=None):
        self.columns_ = sorted({key for row in rows for key in row})
        forbidden = {
            "member_id",
            "user_id",
            "house_id",
            "episode_id",
            "occurrence_id",
        } & set(self.columns_)
        if forbidden:
            raise ValueError("Identity memorization features are forbidden")
        self.numeric_ = [
            key
            for key in self.columns_
            if all(
                row.get(key) is None or isinstance(row[key], (int, float, np.number))
                for row in rows
            )
        ]
        self.categorical_ = [key for key in self.columns_ if key not in self.numeric_]
        self.columns_ = self.numeric_ + self.categorical_
        numeric = [
            (
                "impute",
                SimpleImputer(
                    strategy="median", add_indicator=True, keep_empty_features=True
                ),
            )
        ]
        if self.scale:
            numeric.append(("scale", StandardScaler()))
        if self.encoding == "ordinal":
            categories = [
                sorted(
                    value
                    for value, _ in Counter(
                        str(row[key]) for row in rows if row.get(key) is not None
                    ).most_common(31)
                )
                + [np.nan]
                for key in self.categorical_
            ]
            encoder = OrdinalEncoder(
                categories=categories,
                handle_unknown="use_encoded_value",
                unknown_value=-1,
                encoded_missing_value=-2,
            )
        elif self.encoding == "onehot":
            encoder = OneHotEncoder(
                handle_unknown="ignore", sparse_output=False, max_categories=32
            )
        else:
            raise ValueError("Unknown feature encoding")
        transforms = []
        if self.numeric_:
            transforms.append(
                ("numeric", Pipeline(numeric), list(range(len(self.numeric_))))
            )
        if self.categorical_:
            transforms.append(
                (
                    "categorical",
                    encoder,
                    list(range(len(self.numeric_), len(self.columns_))),
                )
            )
        self.transformer_ = ColumnTransformer(
            transforms, remainder="drop", sparse_threshold=0
        )
        self.transformer_.fit(self.matrix(rows), y)
        return self

    def matrix(self, rows):
        return np.asarray(
            [
                [
                    row.get(key) if row.get(key) is not None else np.nan
                    for key in self.columns_
                ]
                for row in rows
            ],
            dtype=object,
        )

    def transform(self, rows):
        return self.transformer_.transform(self.matrix(rows))

    def manifest(self):
        categorical = self.transformer_.named_transformers_.get("categorical")
        return {
            "numeric_features": self.numeric_,
            "categorical_features": self.categorical_,
            "encoding": self.encoding,
            "category_mapping": {
                key: [
                    str(value) if value == value else "__MISSING__" for value in values
                ]
                for key, values in zip(
                    self.categorical_, getattr(categorical, "categories_", [])
                )
            },
            "onehot_max_categories": 32 if self.encoding == "onehot" else None,
            "ordinal_max_known_categories": 31 if self.encoding == "ordinal" else None,
            "native_categorical": False,
        }
