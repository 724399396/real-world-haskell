import Data.Bits
import Network.Socket
import Network.BSD
import Data.List
import SyslogTypes
import System.IO

data SyslogHandle =
  SyslogHandle {slHandle :: Handle,
                slProgram :: String}

openlog :: HostName         -- ^ Remote hostname, or localhost
        -> String           -- ^ Port number or name; 514 is defulat
        -> String           -- ^ Name to log under
        -> IO SyslogHandle  -- ^ Handle to user for logging

openlog hostname port progname =
  do -- Look up the hostname and prot. Either raises an expceiton
     -- or returns a nonempty list. First element in that list
     -- is supposed to be the best option.
    addrinfos <- getAddrInfo Nothing (Just hostname) (Just port)
    let serveraddr = head addrinfos

    -- Establish a socket for communication
    sock <- socket (addrFamily serveraddr) Stream defaultProtocol

    -- Mark the socket for keep-alive handling sicne it may be idle
    -- for long periods of time
    setSocketOption sock KeepAlive 1

    -- Connect to server
    connect sock (addrAddress serveraddr)

    -- Make a Handle out of it for convenience
    h <- socketToHandle sock WriteMode

    -- We're going to set buffering to BlockBuffering and then
    -- explicitly call hFlush after each message, below, so that
    -- messages get logged immediately
    hSetBuffering h (BlockBuffering Nothing)

    -- Save off the socket, program name, and server address in a handle
    return $ SyslogHandle h progname

syslog :: SyslogHandle -> Facility -> Priority -> String -> IO ()
syslog syslogh fac pri msg =
  do hPutStrLn (slHandle syslogh) sendmsg
     -- Make sure that we send data immediately
     hFlush (slHandle syslogh)
  where code = makeCode fac pri
        sendmsg = "<" ++ show code ++ ">" ++ (slProgram syslogh) ++
                  ": " ++ msg

closelog :: SyslogHandle -> IO ()
closelog syslogh = hClose (slHandle syslogh)

makeCode :: Facility -> Priority -> Int
makeCode fac pri =
  let faccode = codeOfFac fac
      pricode = fromEnum pri
  in
    (faccode `shiftL` 3) .|. pricode

     
