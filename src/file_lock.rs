use std::fs::File;
use std::io;

#[cfg(unix)]
pub fn is_contention(error: &io::Error) -> bool {
    matches!(
        error.raw_os_error(),
        Some(libc::EINTR | libc::EAGAIN | libc::EWOULDBLOCK)
    )
}

#[cfg(windows)]
pub fn is_contention(error: &io::Error) -> bool {
    error.kind() == io::ErrorKind::WouldBlock
}

#[cfg(not(any(unix, windows)))]
pub fn is_contention(_error: &io::Error) -> bool {
    false
}

#[cfg(unix)]
pub fn try_lock_exclusive(file: &File) -> io::Result<()> {
    use std::os::fd::AsRawFd;

    // SAFETY: the file owns a valid descriptor for the duration of the call.
    let result = unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) };
    if result == 0 {
        Ok(())
    } else {
        Err(io::Error::last_os_error())
    }
}

#[cfg(windows)]
pub fn try_lock_exclusive(file: &File) -> io::Result<()> {
    use std::os::windows::io::AsRawHandle;
    use windows_sys::Win32::Storage::FileSystem::{
        LockFileEx, LOCKFILE_EXCLUSIVE_LOCK, LOCKFILE_FAIL_IMMEDIATELY,
    };
    use windows_sys::Win32::System::IO::OVERLAPPED;

    // SAFETY: OVERLAPPED is a C system struct whose all-zero initialization is
    // valid for a synchronous, non-blocking lock of the file's first byte range.
    let mut overlapped: OVERLAPPED = unsafe { std::mem::zeroed() };
    // SAFETY: the file owns a valid handle, and the overlapped struct remains
    // live for the duration of the non-blocking call.
    let result = unsafe {
        LockFileEx(
            file.as_raw_handle() as _,
            LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY,
            0,
            u32::MAX,
            u32::MAX,
            &mut overlapped,
        )
    };
    if result != 0 {
        Ok(())
    } else {
        let error = io::Error::last_os_error();
        if error.raw_os_error() == Some(33) {
            Err(io::Error::from(io::ErrorKind::WouldBlock))
        } else {
            Err(error)
        }
    }
}

#[cfg(not(any(unix, windows)))]
pub fn try_lock_exclusive(_file: &File) -> io::Result<()> {
    Err(io::Error::new(
        io::ErrorKind::Unsupported,
        "exclusive file locking is unsupported on this platform",
    ))
}

#[cfg(unix)]
pub fn unlock(file: &File) -> io::Result<()> {
    use std::os::fd::AsRawFd;

    // SAFETY: the file owns a valid descriptor for the duration of the call.
    let result = unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_UN) };
    if result == 0 {
        Ok(())
    } else {
        Err(io::Error::last_os_error())
    }
}

#[cfg(windows)]
pub fn unlock(file: &File) -> io::Result<()> {
    use std::os::windows::io::AsRawHandle;
    use windows_sys::Win32::Storage::FileSystem::UnlockFileEx;
    use windows_sys::Win32::System::IO::OVERLAPPED;

    // SAFETY: OVERLAPPED is a C system struct whose all-zero initialization
    // describes the same byte range used by try_lock_exclusive.
    let mut overlapped: OVERLAPPED = unsafe { std::mem::zeroed() };
    // SAFETY: the file owns a valid handle and the overlapped struct remains
    // live for the duration of the synchronous unlock call.
    let result = unsafe {
        UnlockFileEx(
            file.as_raw_handle() as _,
            0,
            u32::MAX,
            u32::MAX,
            &mut overlapped,
        )
    };
    if result != 0 {
        Ok(())
    } else {
        Err(io::Error::last_os_error())
    }
}

#[cfg(not(any(unix, windows)))]
pub fn unlock(_file: &File) -> io::Result<()> {
    Err(io::Error::new(
        io::ErrorKind::Unsupported,
        "exclusive file locking is unsupported on this platform",
    ))
}
