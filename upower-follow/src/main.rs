use futures::join;
use serde::Serialize;
use upower_dbus::{BatteryState, BatteryType, DeviceProxy, UPowerProxy};
use zbus::export::futures_util::StreamExt;
use zbus::{Connection, PropertyStream, Result, ResultAdapter};

#[derive(Debug, Serialize)]
struct BatStatus {
    percentage: f64,
    charging: bool,
    icon: String,
    is_battery: bool,
    time_left: String,
}

#[derive(Debug)]
struct BatStatusStream<'c> {
    current_status: BatStatus,
    state_stream: PropertyStream<'c, <Result<BatteryState> as ResultAdapter>::Ok>,
    percentage_stream: PropertyStream<'c, <Result<f64> as ResultAdapter>::Ok>,
    icon_stream: PropertyStream<'c, <Result<String> as ResultAdapter>::Ok>,
    to_empty_stream: PropertyStream<'c, <Result<i64> as ResultAdapter>::Ok>,
    to_full_stream: PropertyStream<'c, <Result<i64> as ResultAdapter>::Ok>,
}

fn is_charging(state: &BatteryState) -> bool {
    return *state == BatteryState::FullyCharged || *state == BatteryState::Charging;
}

fn print_time(time: i64) -> String {
    let seconds = time % 60;
    let minutes = (time / 60) % 60;
    let hours = (time / 60 / 60) % 24;
    let days = time / 60 / 60 / 24;

    let ret = format!("{:02}s", seconds);

    // uhh
    if minutes > 0 || hours > 0 || days > 0 {
        let ret = format!("{:02}m{}", minutes, ret);

        if hours > 0 || days > 0 {
            let ret = format!("{:02}h{}", hours, ret);

            if days > 0 {
                let ret = format!("{:02}d{}", days, ret);
                return ret;
            }
            return ret;
        }
        return ret;
    }
    return ret;
}

impl<'c> BatStatusStream<'c> {
    pub async fn from(device: &DeviceProxy<'c>) -> Result<BatStatusStream<'c>> {
        let results = join!(
            device.percentage(),
            device.state(),
            device.icon_name(),
            device.receive_state_changed(),
            device.receive_percentage_changed(),
            device.receive_icon_name_changed(),
            device.type_(),
            device.get_property::<i64>("TimeToEmpty"),
            device.get_property::<i64>("TimeToFull"),
            device.receive_property_changed::<i64>("TimeToEmpty"),
            device.receive_property_changed::<i64>("TimeToFull"),
        );

        let charging = is_charging(&results.1?);
        Ok(BatStatusStream {
            current_status: BatStatus {
                percentage: results.0?,
                charging,
                icon: results.2?,
                is_battery: results.6? == BatteryType::Battery,
                time_left: print_time(if charging { results.8? } else { results.7? }),
            },
            state_stream: results.3,
            percentage_stream: results.4,
            icon_stream: results.5,
            to_empty_stream: results.9,
            to_full_stream: results.10,
        })
    }

    pub async fn next(&mut self) -> Result<&BatStatus> {
        tokio::select! {
            Some(status) = self.state_stream.next() => {
                self.current_status.charging = is_charging(&status.get().await?);
            }
            Some(icon) = self.icon_stream.next() => {
                self.current_status.icon = icon.get().await?;
            }
            Some(percentage) = self.percentage_stream.next() => {
                self.current_status.percentage = percentage.get().await?;
            }
            Some(to_empty) = self.to_empty_stream.next() => {
                if !self.current_status.charging {
                    self.current_status.time_left = print_time(to_empty.get().await?);
                }
            }
            Some(to_full) = self.to_full_stream.next() => {
                if self.current_status.charging {
                    self.current_status.time_left = print_time(to_full.get().await?);
                }
            }

        }

        Ok(&self.current_status)
    }

    pub fn get(&self) -> &BatStatus {
        &self.current_status
    }
}

#[tokio::main]
async fn main() {
    let conn = Connection::system().await.unwrap();
    let proxy = UPowerProxy::new(&conn).await.unwrap();
    let display = proxy.get_display_device().await.unwrap();

    let device = DeviceProxy::builder(&conn)
        .path(display)
        .unwrap()
        .build()
        .await
        .unwrap();

    let mut stream = BatStatusStream::from(&device).await.unwrap();

    println!("{}", serde_json::to_string(stream.get()).unwrap());
    loop {
        println!(
            "{}",
            serde_json::to_string(stream.next().await.unwrap()).unwrap()
        );
    }
}
