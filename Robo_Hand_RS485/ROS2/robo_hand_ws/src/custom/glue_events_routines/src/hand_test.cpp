#define BACK_PANEL_DIGITAL 1

#include <signal.h>

#include <rclcpp/rclcpp.hpp>

#include <std_msgs/msg/bool.hpp>
#include <xarm_msgs/srv/plan_pose.hpp>
#include <xarm_msgs/srv/plan_joint.hpp>
#include <xarm_msgs/srv/plan_exec.hpp>
#include <xarm_msgs/srv/plan_single_straight.hpp>

#include <std_msgs/msg/string.hpp>
#include <geometry_msgs/msg/transform_stamped.hpp>

#include <std_srvs/srv/set_bool.hpp>
#include <moveit_msgs/srv/servo_command_type.hpp>

#include "xarm_planner/xarm_planner.h"
#include <xarm_msgs/srv/call.hpp>
#include <xarm_msgs/srv/set_digital_io.hpp>

#include <tf2_geometry_msgs/tf2_geometry_msgs.hpp>
#include <ament_index_cpp/get_package_share_directory.hpp>
#include <sstream>
#include <cstdlib>
#include <chrono>
#include <thread>
#include <map>
#include <iomanip>

#include <xarm_msgs/srv/get_set_modbus_data.hpp>

using namespace std::literals::chrono_literals;
using namespace std;

shared_ptr<rclcpp::Node> node;

#define DEBUG(var) \
    do{ \
        RCLCPP_INFO_STREAM(node->get_logger(), #var << " = " << var); \
    }while(0)

#define UNUSED(var) do{ (void)var; }while(0)

void exit_sig_handler(int signum)
{
    UNUSED(signum);
    fprintf(stderr, "[routine_server] Ctrl-C caught, exit process...\n");
    exit(-1);
}

rclcpp::Client<std_srvs::srv::SetBool>::SharedPtr servo_pause__client;
rclcpp::Client<moveit_msgs::srv::ServoCommandType>::SharedPtr servo_sw_cmd__client;

rclcpp::Client<xarm_msgs::srv::Call>::SharedPtr open_gripper__client;
rclcpp::Client<xarm_msgs::srv::Call>::SharedPtr close_gripper__client;
rclcpp::Client<xarm_msgs::srv::Call>::SharedPtr stop_gripper__client;
rclcpp::Client<xarm_msgs::srv::SetDigitalIO>::SharedPtr thumb_pins__client;

rclcpp::Client<xarm_msgs::srv::GetSetModbusData>::SharedPtr modbus_client;

typedef map<string, string> cmds_t;

void exec_hand(const cmds_t& cmds)
{
    shared_ptr<xarm_msgs::srv::Call::Request> gripper_req = make_shared<xarm_msgs::srv::Call::Request>();

    auto set_digital = [&](int pin, bool val) {
        auto thumb_req = make_shared<xarm_msgs::srv::SetDigitalIO::Request>();
        thumb_req->ionum = pin;
        thumb_req->value = val;
        thumb_pins__client->async_send_request(thumb_req);
    };

    if (cmds.at("gripper") != "") {
        if (cmds.at("gripper") == "open") {
#if BACK_PANEL_DIGITAL
            set_digital(0, 0);
#else
            open_gripper__client->async_send_request(gripper_req);
#endif
        } else if (cmds.at("gripper") == "close") {
#if BACK_PANEL_DIGITAL
            set_digital(0, 1);
#else
            close_gripper__client->async_send_request(gripper_req);
#endif
        } else if (cmds.at("gripper") == "stop") {
#if BACK_PANEL_DIGITAL
            set_digital(0, 0);
#else
            stop_gripper__client->async_send_request(gripper_req);
#endif
        }
    }

    if (cmds.at("thumb") != "") {
        if (cmds.at("thumb") == "up") {
#if BACK_PANEL_DIGITAL
            set_digital(1, 1);
#else
            set_digital(0, 1);
            set_digital(1, 0);
#endif
        } else if (cmds.at("thumb") == "down") {
#if BACK_PANEL_DIGITAL
            set_digital(1, 0);
#else
            set_digital(0, 1);
            set_digital(1, 1);
#endif
        } else if (cmds.at("thumb") == "stop") {
#if BACK_PANEL_DIGITAL
            set_digital(1, 0);
#else
            set_digital(0, 0);
#endif
        }
    }

    if (cmds.at("rs485") != "") {
        auto modbus_req = make_shared<xarm_msgs::srv::GetSetModbusData::Request>();
        modbus_req->host_id = 10;                          
        modbus_req->is_transparent_transmission = false;
        modbus_req->use_503_port = false;
        modbus_req->modbus_data = {
            0x00, 0x01,  // Transaction ID
            0x00, 0x02,  // Protocol
            0x00, 0x08,  // Length (samo register, bez parametara)
            0x7F,        // Register: Get error and warning code
            0x09,
            0x0A, 0x15,
            0x00, 0x80, 0x80, 0x43
        };
        modbus_req->modbus_length = 14;
        modbus_req->ret_length = 8;

        modbus_client->async_send_request(
            modbus_req, [](rclcpp::Client<xarm_msgs::srv::GetSetModbusData>::SharedFuture future) {
                auto response = future.get();

                RCLCPP_INFO_STREAM(
                    node->get_logger(),
                    "RS485 ret = " << (int)response->ret
                );

                RCLCPP_INFO_STREAM(
                    node->get_logger(),
                    "RS485 message = " << response->message
                );

                RCLCPP_INFO_STREAM(
                    node->get_logger(),
                    "RS485 ret_data size = " << response->ret_data.size()
                );

                std::stringstream ss;

                for (auto b : response->ret_data) {
                    ss << "0x"
                    << std::hex
                    << std::setw(2)
                    << std::setfill('0')
                    << (int)b
                    << " ";
                }

                RCLCPP_INFO_STREAM(
                    node->get_logger(),
                    "RS485 response bytes: " << ss.str()
                );
            }
        );
    }
}

int main(int argc, char** argv)
{
    rclcpp::init(argc, argv);
    rclcpp::NodeOptions node_options;
    node_options.automatically_declare_parameters_from_overrides(true);
    node = rclcpp::Node::make_shared("routine_server", node_options);
    RCLCPP_INFO(node->get_logger(), "routine_server start");
    signal(SIGINT, exit_sig_handler);

    open_gripper__client = node->create_client<xarm_msgs::srv::Call>("/ufactory/open_lite6_gripper");
    open_gripper__client->wait_for_service(chrono::seconds(3));
    close_gripper__client = node->create_client<xarm_msgs::srv::Call>("/ufactory/close_lite6_gripper");
    close_gripper__client->wait_for_service(chrono::seconds(3));
    stop_gripper__client = node->create_client<xarm_msgs::srv::Call>("/ufactory/stop_lite6_gripper");
    stop_gripper__client->wait_for_service(chrono::seconds(3));

    thumb_pins__client = node->create_client<xarm_msgs::srv::SetDigitalIO>("/ufactory/set_cgpio_digital");
    thumb_pins__client->wait_for_service(chrono::seconds(3));

    servo_pause__client = node->create_client<std_srvs::srv::SetBool>("/servo_server/pause_servo");
    servo_pause__client->wait_for_service(chrono::seconds(1));
    servo_sw_cmd__client = node->create_client<moveit_msgs::srv::ServoCommandType>("/servo_server/switch_command_type");
    servo_sw_cmd__client->wait_for_service(chrono::seconds(1));

    modbus_client = node->create_client<xarm_msgs::srv::GetSetModbusData>("/ufactory/getset_tgpio_modbus_data");
    modbus_client->wait_for_service(chrono::seconds(3));

    cmds_t cmds;
    cmds["gripper"] = "";
    cmds["thumb"]   = "";
    cmds["rs485"]   = "get_error";

    RCLCPP_INFO(node->get_logger(), "Sending RS485 test command...");
    exec_hand(cmds);

    // spin obrađuje async callback u kome se loguje odgovor
    rclcpp::spin(node);
    rclcpp::shutdown();
    return 0;
}