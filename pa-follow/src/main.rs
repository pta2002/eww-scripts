use core::cell::RefCell;
use pulse::callbacks::ListResult;
use pulse::context::introspect::SinkInfo;
use pulse::context::subscribe::InterestMaskSet;
use pulse::context::{Context, FlagSet, State};
use pulse::mainloop::standard::{IterateResult, Mainloop};
use serde::Serialize;
use std::ops::Deref;
use std::rc::Rc;

#[derive(Debug, Serialize)]
struct SinkInfoPrint {
    volume: usize,
    muted: bool,
}

fn print_sink_info(info: &SinkInfo) {
    let volume = info.volume.get()[0];
    let volume = volume
        .print()
        .trim_start()
        .strip_suffix("%")
        .unwrap_or("0")
        .parse::<usize>()
        .unwrap_or(0);
    let muted = info.mute;

    let print_info = SinkInfoPrint { volume, muted };

    println!("{}", serde_json::to_string(&print_info).unwrap());
}

fn main() {
    let mainloop = Rc::new(RefCell::new(Mainloop::new().unwrap()));

    let ctx = Rc::new(RefCell::new(
        Context::new(mainloop.borrow().deref(), "pa-follow").expect("failed to create PA context"),
    ));

    ctx.borrow_mut()
        .connect(None, FlagSet::NOFLAGS, None)
        .expect("failed to connect to PA server");

    let introspect = ctx.borrow_mut().introspect();

    ctx.borrow_mut()
        .set_subscribe_callback(Some(Box::new(move |_, _, sink| {
            introspect.get_sink_info_by_index(sink, |res| {
                if let ListResult::Item(i) = res {
                    print_sink_info(&i);
                }
            });
        })));

    loop {
        match mainloop.borrow_mut().iterate(false) {
            IterateResult::Err(_) => {
                eprintln!("iterate state failed");
                return;
            }
            IterateResult::Success(_) => {}
            IterateResult::Quit(_) => {
                eprintln!("iterate state was ordered to quit");
                return;
            }
        }

        match ctx.borrow().get_state() {
            State::Ready => break,
            State::Failed | State::Terminated => {
                eprintln!("context state failed");
                return;
            }
            _ => {}
        }
    }

    // By this point, we're connected

    // To get volume:
    // 1. get server info
    // 2. on the info, get the main device
    // 3. from this, we can get the sink using get_sink_info_by_name
    let introspect = ctx.borrow_mut().introspect();
    let introspect2 = ctx.borrow_mut().introspect();
    introspect.get_server_info(move |info| {
        if let Some(name) = &info.default_sink_name {
            introspect2.get_sink_info_by_name(&name, |info| {
                if let ListResult::Item(sink) = info {
                    print_sink_info(sink);
                }
            });
        }
    });

    ctx.borrow_mut().subscribe(InterestMaskSet::SINK, |_| {});

    mainloop.borrow_mut().run().expect("couldn't run main loop");
}
