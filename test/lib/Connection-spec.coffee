{EventEmitter} = require 'events'
Connection     = require '../../lib/Connection'
NodeRSA = require 'node-rsa'

describe 'Connection', ->
  describe 'when we pass in a fake socket.io', ->
    beforeEach ->
      @console = error: sinon.spy()
      @sut = new Connection( {}, {
        socketIoClient: -> new EventEmitter(),
        console: @console
      })

    it 'should instantiate', ->
      expect(@sut).to.exist

    describe 'when connect, then ready, then disconnect', ->
      beforeEach ->
        @socket = @sut.socket
        @socket.emit 'connect'
        @socket.emit 'ready', {uuid: 'cats', token: 'dogs'}
        @socket.emit 'disconnect'

      it 'should emit the uuid and token on identify', (done) ->
        @socket.on 'identity', (config) ->
          expect(config.uuid).to.deep.equal 'cats'
          expect(config.token).to.deep.equal 'dogs'
          done()
        @socket.emit 'identify'

    it 'should have a function called "resetToken"', ->
      expect(@sut.resetToken).to.exist

    describe 'when resetToken is called with a uuid', ->
      beforeEach ->
        @sut.socket.emit = sinon.spy @sut.socket.emit
      it 'emit resetToken with the uuid', ->
        @sut.resetToken 'uuid'
        expect(@sut.socket.emit).to.have.been.calledWith 'resetToken', uuid: 'uuid'

    describe 'when resetToken is called with a different uuid', ->
      beforeEach ->
        @sut.socket.emit = sinon.spy @sut.socket.emit
      it 'emit resetToken with the uuid', ->
        @sut.resetToken 'uuid2'
        expect(@sut.socket.emit).to.have.been.calledWith 'resetToken', uuid: 'uuid2'

    describe 'when resetToken is called with an object containing a uuid', ->
      beforeEach ->
        @sut.socket.emit = sinon.spy @sut.socket.emit
      it 'emit resetToken with the uuid', ->
        @sut.resetToken uuid: 'uuid3'
        expect(@sut.socket.emit).to.have.been.calledWith 'resetToken', uuid:'uuid3'

    describe 'when resetToken is called with a uuid and a callback', ->
      beforeEach ->
        @sut.socket.emit = sinon.spy @sut.socket.emit
      it 'emit resetToken with the uuid', ->
        @callback = =>
        @sut.resetToken 'uuid4', @callback
        expect(@sut.socket.emit).to.have.been.calledWith 'resetToken', uuid:'uuid4', @callback


    describe 'encryptMessage', ->
      it 'should exist', ->
        expect(@sut.encryptMessage).to.exist

      beforeEach ->
        @sut.getPublicKey = sinon.stub()

      describe 'when encryptMessage is called with a device of uuid 1', ->
        it 'should call getPublicKey', ->
          @sut.encryptMessage 1
          expect(@sut.getPublicKey).to.have.been.called

        it 'should call getPublicKey with the uuid of the target device 1', ->
          @sut.encryptMessage 1
          expect(@sut.getPublicKey).to.have.been.calledWith 1

        describe 'when getPublicKey returns with a public key', ->
          beforeEach ->
            @publicKey = encrypt: sinon.stub().returns '54321'
            @sut.getPublicKey.yields null, @publicKey

          it 'should call encrypt on the response from getPublicKey', ->
            @sut.encryptMessage 1, hello : 'world'
            expect(@publicKey.encrypt).to.have.been.calledWith JSON.stringify(hello : 'world')

          describe 'when publicKey.encrypt returns with a buffer of "12345"', ->
            beforeEach ->
              @sut.message = sinon.spy @sut.message
              @publicKey.encrypt.returns new Buffer '12345',

            it 'should call message with an encrypted payload', ->
              @sut.encryptMessage 1, hello : 'world'
              expect(@sut.message).to.have.been.calledWith 1, undefined, encryptedPayload: 'MTIzNDU='



        describe 'when getPublicKey returns with an error', ->
          beforeEach ->
            @sut.getPublicKey.yields true, null

          it 'should call console.error and report the error', ->
            @sut.encryptMessage 1, { hello : 'world' }
            expect(@console.error).to.have.been.calledWith 'can\'t find public key for device'


      describe 'when encryptMessage is called with a different uuid', ->
        it 'should call getPublicKey with the uuid of the target device', ->
          @sut.encryptMessage 2
          expect(@sut.getPublicKey).to.have.been.calledWith 2

    describe 'getPublicKey', ->
      it 'should exist', ->
        expect(@sut.getPublicKey).to.exist

      describe 'when called', ->
        beforeEach () ->
          @sut.device = sinon.stub()
          @callback = sinon.spy()

        it 'should call device on itself with the uuid of the device we are getting the key for', ->
          @sut.getPublicKey 'c9707ff2-b3e7-4363-b164-90f5753dac68', @callback
          expect(@sut.device).to.have.been.calledWith uuid: 'c9707ff2-b3e7-4363-b164-90f5753dac68'

        describe 'when called with a different uuid', ->
          it 'should call device with the different uuid', ->
            @sut.getPublicKey '4df5ee81-8f60-437d-8c19-2375df745b70', @callback
            expect(@sut.device).to.have.been.calledWith uuid: '4df5ee81-8f60-437d-8c19-2375df745b70'

          describe 'when device returns an invalid device', ->
            beforeEach ->
              @sut.device.yields new Error('you suck'), null

            it 'should call the callback with an error', ->
              @sut.getPublicKey 'c9707ff2-b3e7-4363-b164-90f5753dac68', @callback
              error = @callback.args[0][0]
              expect(error).to.exist

          describe 'when device returns a valid device without a public key', ->
            beforeEach ->
              @device = {}
              @sut.device.yields undefined, @device

            it 'should call the callback with an error', ->
              @sut.getPublicKey 'c9707ff2-b3e7-4363-b164-90f5753dac68', @callback
              error = @callback.args[0][0]
              expect(error).to.exist

          describe 'when device returns a valid device with a public key', ->
            beforeEach ->
              @device =
                publicKey: '-----BEGIN PUBLIC KEY-----\nMFswDQYJKoZIhvcNAQEBBQADSgAwRwJAX9eHOOux3ycXbc/FVzM+z9OQeouRePWA\nT0QRcsAHeDNy4HwNrME7xxI2LH36g8H3S+zCapYYdCyc1LwSDEAfcQIDAQAB\n-----END PUBLIC KEY-----'

              @privateKey = new NodeRSA '-----BEGIN RSA PRIVATE KEY-----\nMIIBOAIBAAJAX9eHOOux3ycXbc/FVzM+z9OQeouRePWAT0QRcsAHeDNy4HwNrME7\nxxI2LH36g8H3S+zCapYYdCyc1LwSDEAfcQIDAQABAkA+59C6PIDvzdGj4rZM6La2\nY881j7u4n7JK1It7PKzqaFPzY+Aee0tRp1kOF8+/xOG1NGYLFyYBbCM38bnjnkwB\nAiEAqzkA7zUZl1at5zoERm9YyV/FUntQWBYCvdWS+5U7G8ECIQCPS8hY8yZwOL39\n8JuCJl5TvkGRg/w3GFjAo1kwJKmvsQIgNoRw8rlCi7hSqNQFNnQPnha7WlbfLxzb\nBJyzLx3F80ECIGjiPi2lI5BmZ+IUF67mqIpBKrr40UX+Yw/1QBW18CGxAiBPN3i9\nIyTOw01DUqSmXcgrhHJM0RogYtJbpJkT6qbPXw==\n-----END RSA PRIVATE KEY-----'
              @sut.device.yields undefined, { device: @device }

            it 'should call the callback without an error', ->
              @sut.getPublicKey 'c9707ff2-b3e7-4363-b164-90f5753dac68', @callback
              error = @callback.args[0][0]
              expect(error).to.not.exist

            it 'should only call the callback once', ->
              @sut.getPublicKey 'c9707ff2-b3e7-4363-b164-90f5753dac68', @callback
              expect(@callback.calledOnce).to.be.true

            it 'should return an object with a method encrypt', ->
              @sut.getPublicKey 'c9707ff2-b3e7-4363-b164-90f5753dac68', @callback
              key = @callback.args[0][1]
              expect(key.encrypt).to.exist

            describe 'when encrypt is called with a message on the returned key', ->
              beforeEach ->
                @sut.getPublicKey 'c9707ff2-b3e7-4363-b164-90f5753dac68', @callback
                key = @callback.args[0][1]
                @encryptedMessage = key.encrypt('hi').toString 'base64'

              it 'should be able to decrypt the result with the private key', ->
                decryptedMessage = @privateKey.decrypt(@encryptedMessage).toString()
                expect(decryptedMessage).to.equal 'hi'

    describe 'when we create a connection with a private key', ->
      beforeEach ->
        @console = error: sinon.spy()
        @privateKey = '-----BEGIN RSA PRIVATE KEY-----\nMIIBOAIBAAJAX9eHOOux3ycXbc/FVzM+z9OQeouRePWAT0QRcsAHeDNy4HwNrME7\nxxI2LH36g8H3S+zCapYYdCyc1LwSDEAfcQIDAQABAkA+59C6PIDvzdGj4rZM6La2\nY881j7u4n7JK1It7PKzqaFPzY+Aee0tRp1kOF8+/xOG1NGYLFyYBbCM38bnjnkwB\nAiEAqzkA7zUZl1at5zoERm9YyV/FUntQWBYCvdWS+5U7G8ECIQCPS8hY8yZwOL39\n8JuCJl5TvkGRg/w3GFjAo1kwJKmvsQIgNoRw8rlCi7hSqNQFNnQPnha7WlbfLxzb\nBJyzLx3F80ECIGjiPi2lI5BmZ+IUF67mqIpBKrr40UX+Yw/1QBW18CGxAiBPN3i9\nIyTOw01DUqSmXcgrhHJM0RogYtJbpJkT6qbPXw==\n-----END RSA PRIVATE KEY-----'
        @NodeRSA = sinon.stub()

        @sut = new Connection( { privateKey: @privateKey }, {
          socketIoClient: -> new EventEmitter(),
          NodeRSA : @NodeRSA,
          console: @console
        })


      it 'should call NodeRSA with the private key passed in', ->
        expect(@NodeRSA).to.have.been.calledWith @privateKey
      describe 'when we get a message with an "encryptedPayload" property', ->
        it 'should decrypt the encryptedPayload before emitting it to the user', ->


    describe 'message', ->
      beforeEach ->
        @sut._emitWithAck = sinon.stub()

      describe 'when message is called with a uuid and a message body', ->
        it 'should call emitWithAck with an object with a devices and payload property', ->
          @object = {}
          @sut.message 1, @object
          messageObject = @sut._emitWithAck.args[0][1]
          expect(messageObject).to.deep.equal {devices: 1, payload: @object}

      describe 'when message is called with a different uuid and message body', ->
        it 'should call emitWithAck with an object with that uuid and payload', ->
          @object = hello: 'world'
          @sut.message 2, @object
          messageObject = @sut._emitWithAck.args[0][1]
          expect(messageObject).to.deep.equal {devices: 2, payload: @object}

      describe 'when message is called with a callback', ->
         it 'should call emitWithAck with a callback', ->
          @callback = sinon.spy()
          @object = {}
          @sut.message 1, @object, @callback
          passedCallback = @sut._emitWithAck.args[0][2]
          expect(passedCallback).to.equal @callback

      describe 'when message is called the old way, with one big object', ->
        it 'should call _emitWithAck with the entire object and a callback', ->
          callback = sinon.spy()
          message = devices: [ 1 ], payload: { hello: 'world' }
          @sut.message message, callback

          expect(@sut._emitWithAck).to.have.been.calledWith 'message', message, callback

      describe 'when message is called with options', ->
        it 'should call _emitWithAck with an object with the options in it', ->
          callback = sinon.spy()
          message = cats: true
          options = hello: 'world'
          messageObject = {
            devices: [1],
            payload:
              cats: true,
            hello: 'world'
          }
          @sut.message [1], message, options, callback

          emitArgs = @sut._emitWithAck.args[0]
          expect(emitArgs[1]).to.deep.equal messageObject





