import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('display_layout', Path(__file__).resolve().parents[1] / 'config/sketchybar/plugins/display-layout.py')
layout = importlib.util.module_from_spec(spec)
spec.loader.exec_module(layout)


class DisplayLayoutTests(unittest.TestCase):
    def test_mixed_displays_and_reordered_monitor_ids(self):
        screens = [dict(screen=1, notch=True, inset=32, height=33),
                   dict(screen=2, notch=False, inset=0, height=30)]
        monitors = [{'monitor-id': 2, 'monitor-appkit-nsscreen-screens-id': 1},
                    {'monitor-id': 1, 'monitor-appkit-nsscreen-screens-id': 2}]
        props, gaps = layout.plan(screens, monitors)
        self.assertEqual(props, ['height=30', 'notch_display_height=33'])
        self.assertIn('monitor."1" = 35', gaps)
        self.assertIn('monitor."2" = 6', gaps)

    def test_different_external_heights_fit_under_both_menus(self):
        screens = [dict(screen=1, notch=False, inset=0, height=30),
                   dict(screen=2, notch=False, inset=24, height=24)]
        monitors = [{'monitor-id': i, 'monitor-appkit-nsscreen-screens-id': i} for i in (1, 2)]
        props, gaps = layout.plan(screens, monitors)
        self.assertEqual(props, ['height=24'])
        self.assertIn('monitor."1" = 29', gaps)
        self.assertIn('monitor."2" = 5', gaps)

    def test_incomplete_menu_measurement_is_retried(self):
        with self.assertRaises(ValueError):
            layout.plan([dict(screen=1, notch=False, inset=0, height=None)], [])

    def test_changing_topology_does_not_generate_wrong_gaps(self):
        with self.assertRaises(ValueError):
            layout.plan([dict(screen=1, notch=False, inset=0, height=30)], [])


if __name__ == '__main__':
    unittest.main()
