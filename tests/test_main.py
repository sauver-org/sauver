import json
from src.main import tracker_shield


def test_tracker_shield_no_trackers() -> None:
    html = "<p>Hello world</p>"
    result_str = tracker_shield(html)
    result = json.loads(result_str)
    assert result["trackers_neutralized"] == 0
    assert result["cleaned_html"] == html


def test_tracker_shield_with_trackers() -> None:
    html = '<p>Hello world</p><img src="http://track.me/pixel" width="1" height="1">'
    result_str = tracker_shield(html)
    result = json.loads(result_str)
    assert result["trackers_neutralized"] == 1
    assert result["cleaned_html"] == "<p>Hello world</p>"


def test_tracker_shield_multiple_trackers() -> None:
    html = '<p>Hello world</p><img src="1" height="1" width="1"><img width="1" src="2" height="1">'
    result_str = tracker_shield(html)
    result = json.loads(result_str)
    assert result["trackers_neutralized"] == 2
    assert result["cleaned_html"] == "<p>Hello world</p>"


def test_tracker_shield_by_keyword() -> None:
    html = '<p>Hello world</p><img src="https://recruiterflow.com/email-tracking/abc.gif">'
    result_str = tracker_shield(html)
    result = json.loads(result_str)
    assert result["trackers_neutralized"] == 1
    assert result["cleaned_html"] == "<p>Hello world</p>"
