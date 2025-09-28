#!/usr/bin/env python3
"""
企业微信值班通知脚本
定时发送今日值班和明日值班员工信息
"""

import os
import json
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import logging

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class WeChatNotifier:
    """企业微信通知类"""
    
    def __init__(self, webhook_url: str):
        self.webhook_url = webhook_url
        self.headers = {'Content-Type': 'application/json'}
    
    def send_markdown_message(self, content: str) -> bool:
        """发送 Markdown 格式的消息"""
        data = {
            "msgtype": "markdown",
            "markdown": {
                "content": content
            }
        }
        
        try:
            response = requests.post(
                self.webhook_url, 
                headers=self.headers, 
                data=json.dumps(data, ensure_ascii=False).encode('utf-8'),
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get('errcode') == 0:
                    logger.info("企业微信消息发送成功")
                    return True
                else:
                    logger.error(f"企业微信消息发送失败: {result}")
                    return False
            else:
                logger.error(f"HTTP请求失败: {response.status_code}")
                return False
                
        except Exception as e:
            logger.error(f"发送消息异常: {e}")
            return False


class DutyScheduleManager:
    """值班排班管理类"""
    
    def __init__(self, config_file: str = 'duty_schedule.json'):
        script_dir = os.path.dirname(os.path.realpath(__file__))
        self.config_file = os.path.join(script_dir, config_file)
        self.duty_schedule = self.load_schedule()
    
    def load_schedule(self) -> Dict:
        """加载值班排班配置"""
        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except FileNotFoundError:
            logger.error(f"配置文件 {self.config_file} 不存在")
            return {}
        except json.JSONDecodeError as e:
            logger.error(f"配置文件格式错误: {e}")
            return {}
    
    def get_duty_person(self, date: datetime) -> Optional[Dict]:
        """根据日期获取值班人员信息"""
        if not self.duty_schedule:
            return None
        
        # 获取星期几 (0=周一, 6=周日)
        weekday = date.weekday()
        weekday_name = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][weekday]
        
        # 先检查特殊日期配置
        date_str = date.strftime('%Y-%m-%d')
        if 'special_dates' in self.duty_schedule:
            special_duty = self.duty_schedule['special_dates'].get(date_str)
            if special_duty:
                return special_duty
        
        # 检查周循环配置
        if 'weekly_schedule' in self.duty_schedule:
            weekly_duty = self.duty_schedule['weekly_schedule'].get(weekday_name.lower())
            if weekly_duty:
                return weekly_duty
        
        # 检查日循环配置
        if 'daily_rotation' in self.duty_schedule:
            rotation = self.duty_schedule['daily_rotation']
            if rotation['employees']:
                # 计算从起始日期开始的天数
                start_date = datetime.strptime(rotation['start_date'], '%Y-%m-%d')
                days_diff = (date.date() - start_date.date()).days
                index = days_diff % len(rotation['employees'])
                return rotation['employees'][index]
        
        return None
    
    def format_duty_info(self, duty_person: Dict, date: datetime, is_today: bool = True) -> str:
        """格式化值班人员信息"""
        if not duty_person:
            date_label = "今日" if is_today else "明日"
            return f"**{date_label}值班 ({date.strftime('%Y-%m-%d %A')})**: 暂无安排"
        
        date_label = "今日" if is_today else "明日"
        name = duty_person.get('name', '未知')
        phone = duty_person.get('phone', '')
        department = duty_person.get('department', '')
        
        info = f"**{date_label}值班 ({date.strftime('%Y-%m-%d %A')})**\n"
        info += f"👤 值班人员: {name}\n"
        
        if department:
            info += f"🏢 所属部门: {department}\n"
        
        if phone:
            info += f"📞 联系电话: {phone}\n"
        
        return info

    def get_rotation_string(self) -> str:
        """获取值班轮换顺序字符串"""
        if 'daily_rotation' in self.duty_schedule and self.duty_schedule['daily_rotation']['employees']:
            employees = self.duty_schedule['daily_rotation']['employees']
            names = [emp.get('name', '未知') for emp in employees]
            return ' -> '.join(names)
        return ""

def main():
    """主函数"""
    # 从环境变量获取企业微信 Webhook URL
    webhook_url = os.getenv('WECHAT_WEBHOOK')
    if not webhook_url:
        logger.error("未找到环境变量 WECHAT_WEBHOOK")
        return
    
    # 初始化通知器和排班管理器
    notifier = WeChatNotifier(webhook_url)
    schedule_manager = DutyScheduleManager()
    
    # 获取今天和明天的日期
    today = datetime.now()
    tomorrow = today + timedelta(days=1)
    
    # 获取值班人员信息
    today_duty = schedule_manager.get_duty_person(today)
    tomorrow_duty = schedule_manager.get_duty_person(tomorrow)
    
    # 获取值班轮换顺序
    rotation_string = schedule_manager.get_rotation_string()
    
    # 格式化消息内容
    message_content = f"""# 📋 值班通知

{schedule_manager.format_duty_info(today_duty, today, is_today=True)}

{schedule_manager.format_duty_info(tomorrow_duty, tomorrow, is_today=False)}

---
⏰ 通知时间: {today.strftime('%Y-%m-%d %H:%M:%S')}
🤖 自动发送 by GitHub Actions"""

    if rotation_string:
        message_content += f"\n\n值班顺序: {rotation_string}"
    
    # 发送通知
    success = notifier.send_markdown_message(message_content)
    
    if success:
        print("✅ 值班通知发送成功")
    else:
        print("❌ 值班通知发送失败")
        exit(1)


if __name__ == "__main__":
    main()
