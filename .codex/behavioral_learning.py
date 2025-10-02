#!/usr/bin/env python3
"""
Behavioral Learning System for AI Assistant
Analyzes user interactions and learns patterns
"""

import json
import yaml
import os
from datetime import datetime
from typing import Dict, List, Any
import re

class BehavioralLearning:
    def __init__(self, profile_path: str = ".codex/user_profile.yml"):
        self.profile_path = profile_path
        self.interaction_history = []
        self.learning_patterns = {}
        self.user_preferences = {}
        
    def load_user_profile(self) -> Dict[str, Any]:
        """Load user profile from YAML file"""
        try:
            with open(self.profile_path, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            return {}
        except Exception as e:
            print(f"Error loading user profile: {e}")
            return {}
    
    def analyze_interaction(self, interaction: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze a single interaction for patterns"""
        patterns = {
            'communication_style': self._analyze_communication_style(interaction),
            'working_approach': self._analyze_working_approach(interaction),
            'problem_solving': self._analyze_problem_solving(interaction),
            'preferences': self._analyze_preferences(interaction)
        }
        return patterns
    
    def _analyze_communication_style(self, interaction: Dict[str, Any]) -> Dict[str, float]:
        """Analyze communication style patterns"""
        text = interaction.get('text', '').lower()
        
        # Language analysis
        thai_chars = len(re.findall(r'[\u0e00-\u0e7f]', text))
        english_chars = len(re.findall(r'[a-zA-Z]', text))
        total_chars = len(text)
        
        thai_ratio = thai_chars / total_chars if total_chars > 0 else 0
        english_ratio = english_chars / total_chars if total_chars > 0 else 0
        
        # Style indicators
        detailed_explanation = 1.0 if len(text) > 100 else 0.5
        confirmation_required = 1.0 if any(word in text for word in ['ใช่', 'ใช่ไหม', 'ได้ไหม', 'ok', 'confirm']) else 0.0
        step_by_step = 1.0 if any(word in text for word in ['ขั้นตอน', 'step', 'ทีละ', 'ลำดับ']) else 0.0
        
        return {
            'thai_english_mixed': (thai_ratio + english_ratio) / 2,
            'detailed_explanations': detailed_explanation,
            'confirmation_required': confirmation_required,
            'step_by_step': step_by_step
        }
    
    def _analyze_working_approach(self, interaction: Dict[str, Any]) -> Dict[str, float]:
        """Analyze working approach patterns"""
        text = interaction.get('text', '').lower()
        
        # Working style indicators
        systematic = 1.0 if any(word in text for word in ['ระบบ', 'systematic', 'เป็นระบบ', 'order']) else 0.0
        testing = 1.0 if any(word in text for word in ['test', 'ทดสอบ', 'verify', 'check']) else 0.0
        documentation = 1.0 if any(word in text for word in ['doc', 'document', 'เอกสาร', 'อธิบาย']) else 0.0
        optimization = 1.0 if any(word in text for word in ['optimize', 'ปรับปรุง', 'improve', 'better']) else 0.0
        
        return {
            'systematic_approach': systematic,
            'testing_before_commit': testing,
            'comprehensive_documentation': documentation,
            'optimization_focused': optimization
        }
    
    def _analyze_problem_solving(self, interaction: Dict[str, Any]) -> Dict[str, float]:
        """Analyze problem-solving patterns"""
        text = interaction.get('text', '').lower()
        
        # Problem-solving indicators
        analytical = 1.0 if any(word in text for word in ['วิเคราะห์', 'analyze', 'คิด', 'consider']) else 0.0
        methodical = 1.0 if any(word in text for word in ['วิธี', 'method', 'ขั้นตอน', 'process']) else 0.0
        detail_oriented = 1.0 if any(word in text for word in ['ละเอียด', 'detail', 'specific', 'ชัดเจน']) else 0.0
        solution_focused = 1.0 if any(word in text for word in ['แก้', 'solve', 'fix', 'resolve']) else 0.0
        
        return {
            'analytical': analytical,
            'methodical': methodical,
            'detail_oriented': detail_oriented,
            'solution_focused': solution_focused
        }
    
    def _analyze_preferences(self, interaction: Dict[str, Any]) -> Dict[str, float]:
        """Analyze user preferences"""
        text = interaction.get('text', '').lower()
        
        # Preference indicators
        visual_learner = 1.0 if any(word in text for word in ['ดู', 'see', 'show', 'display', 'visual']) else 0.0
        hands_on = 1.0 if any(word in text for word in ['ทำ', 'do', 'run', 'execute', 'ลอง']) else 0.0
        example_based = 1.0 if any(word in text for word in ['ตัวอย่าง', 'example', 'sample', 'demo']) else 0.0
        documentation_reader = 1.0 if any(word in text for word in ['อ่าน', 'read', 'doc', 'manual']) else 0.0
        
        return {
            'visual_learner': visual_learner,
            'hands_on': hands_on,
            'example_based': example_based,
            'documentation_reader': documentation_reader
        }
    
    def learn_from_interaction(self, interaction: Dict[str, Any]) -> None:
        """Learn from a new interaction"""
        patterns = self.analyze_interaction(interaction)
        
        # Update learning patterns
        for category, patterns_dict in patterns.items():
            if category not in self.learning_patterns:
                self.learning_patterns[category] = {}
            
            for pattern, value in patterns_dict.items():
                if pattern not in self.learning_patterns[category]:
                    self.learning_patterns[category][pattern] = []
                
                self.learning_patterns[category][pattern].append({
                    'value': value,
                    'timestamp': datetime.now().isoformat(),
                    'confidence': 0.8  # Default confidence
                })
        
        # Keep only recent patterns (last 100)
        for category in self.learning_patterns:
            for pattern in self.learning_patterns[category]:
                if len(self.learning_patterns[category][pattern]) > 100:
                    self.learning_patterns[category][pattern] = self.learning_patterns[category][pattern][-100:]
    
    def predict_user_needs(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Predict what user needs based on learned patterns"""
        predictions = {
            'communication_style': self._predict_communication_style(),
            'working_approach': self._predict_working_approach(),
            'problem_solving': self._predict_problem_solving(),
            'preferences': self._predict_preferences()
        }
        return predictions
    
    def _predict_communication_style(self) -> Dict[str, float]:
        """Predict communication style preferences"""
        if 'communication_style' not in self.learning_patterns:
            return {}
        
        predictions = {}
        for pattern, history in self.learning_patterns['communication_style'].items():
            if history:
                # Calculate average with recent bias
                recent_values = [h['value'] for h in history[-10:]]
                predictions[pattern] = sum(recent_values) / len(recent_values)
        
        return predictions
    
    def _predict_working_approach(self) -> Dict[str, float]:
        """Predict working approach preferences"""
        if 'working_approach' not in self.learning_patterns:
            return {}
        
        predictions = {}
        for pattern, history in self.learning_patterns['working_approach'].items():
            if history:
                recent_values = [h['value'] for h in history[-10:]]
                predictions[pattern] = sum(recent_values) / len(recent_values)
        
        return predictions
    
    def _predict_problem_solving(self) -> Dict[str, float]:
        """Predict problem-solving preferences"""
        if 'problem_solving' not in self.learning_patterns:
            return {}
        
        predictions = {}
        for pattern, history in self.learning_patterns['problem_solving'].items():
            if history:
                recent_values = [h['value'] for h in history[-10:]]
                predictions[pattern] = sum(recent_values) / len(recent_values)
        
        return predictions
    
    def _predict_preferences(self) -> Dict[str, float]:
        """Predict user preferences"""
        if 'preferences' not in self.learning_patterns:
            return {}
        
        predictions = {}
        for pattern, history in self.learning_patterns['preferences'].items():
            if history:
                recent_values = [h['value'] for h in history[-10:]]
                predictions[pattern] = sum(recent_values) / len(recent_values)
        
        return predictions
    
    def adapt_style(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Adapt AI style based on learned patterns"""
        predictions = self.predict_user_needs(context)
        
        adaptations = {
            'communication': {
                'use_thai_english': predictions.get('communication_style', {}).get('thai_english_mixed', 0.5) > 0.7,
                'detailed_explanations': predictions.get('communication_style', {}).get('detailed_explanations', 0.5) > 0.7,
                'ask_confirmation': predictions.get('communication_style', {}).get('confirmation_required', 0.5) > 0.7,
                'step_by_step': predictions.get('communication_style', {}).get('step_by_step', 0.5) > 0.7
            },
            'working': {
                'systematic_approach': predictions.get('working_approach', {}).get('systematic_approach', 0.5) > 0.7,
                'testing_focus': predictions.get('working_approach', {}).get('testing_before_commit', 0.5) > 0.7,
                'documentation_focus': predictions.get('working_approach', {}).get('comprehensive_documentation', 0.5) > 0.7
            },
            'problem_solving': {
                'analytical_approach': predictions.get('problem_solving', {}).get('analytical', 0.5) > 0.7,
                'methodical_approach': predictions.get('problem_solving', {}).get('methodical', 0.5) > 0.7,
                'detail_focus': predictions.get('problem_solving', {}).get('detail_oriented', 0.5) > 0.7
            }
        }
        
        return adaptations
    
    def save_learning(self, output_path: str = ".codex/learning_patterns.json") -> None:
        """Save learned patterns to file"""
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(self.learning_patterns, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Error saving learning patterns: {e}")
    
    def load_learning(self, input_path: str = ".codex/learning_patterns.json") -> None:
        """Load learned patterns from file"""
        try:
            with open(input_path, 'r', encoding='utf-8') as f:
                self.learning_patterns = json.load(f)
        except FileNotFoundError:
            self.learning_patterns = {}
        except Exception as e:
            print(f"Error loading learning patterns: {e}")

def main():
    """Main function for testing"""
    learning = BehavioralLearning()
    
    # Example interaction
    interaction = {
        'text': 'คุณช่วยอธิบายให้ละเอียดหน่อยได้ไหม ผมต้องการทำความเข้าใจขั้นตอนการทำงาน',
        'timestamp': datetime.now().isoformat(),
        'context': 'asking_for_explanation'
    }
    
    # Learn from interaction
    learning.learn_from_interaction(interaction)
    
    # Predict user needs
    predictions = learning.predict_user_needs({})
    print("Predicted user needs:", predictions)
    
    # Adapt style
    adaptations = learning.adapt_style({})
    print("Style adaptations:", adaptations)
    
    # Save learning
    learning.save_learning()

if __name__ == "__main__":
    main()
