# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information
import os
import sys
# Pythonスクリプト(generate_terraform.py)があるディレクトリへのパスを通す
sys.path.insert(0, os.path.abspath('../..'))

project = 'CSV to Terraform Converter'
copyright = '2025, eA Mitsuoka'
author = 'eA Mitsuoka'
release = '0.1'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.autodoc',   # docstringからドキュメントを自動生成
    'sphinx.ext.napoleon',  # Google/NumPyスタイルのdocstringを解釈
    'sphinx.ext.viewcode',  # ソースコードへのリンクを追加
]

templates_path = ['_templates']
exclude_patterns = []

language = 'ja'

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'sphinx_rtd_theme' # 見やすいテーマに変更
html_static_path = ['_static']
