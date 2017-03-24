using DecimalNumbers, Base.Test

@testset "from int" begin
    d = DecimalNumbers.Decimal(1)
    @test d.value == 1
    @test d.exp == 0
    # denormalize
    d = DecimalNumbers.Decimal(10)
    @test d.value == 1
    @test d.exp == 1

    d = DecimalNumbers.Decimal(23487300)
    @test d.value == 234873
    @test d.exp == 2

    # specific integer type
    d = DecimalNumbers.Decimal(Int8(40))
    @test typeof(d.value) == Int8
    @test d.value === Int8(4)
    @test d.exp === Int8(1)
end

@testset "to int" begin
    d = DecimalNumbers.Decimal(1)
    @test Int(d) === 1

    d = DecimalNumbers.Decimal(23487300)
    @test Int(d) === 23487300

    @test_throws InexactError Int(DecimalNumbers.Decimal(3.14))
end

@testset "from float" begin
    d = DecimalNumbers.Decimal(3.0)
    @test d.value == 3
    @test d.exp == 0

    d = DecimalNumbers.Decimal(3.14)
    @test d.value == 314
    @test d.exp == -2
    @test typeof(d.value) == Int64

    d = DecimalNumbers.Decimal(Float16(-3.14))
    @test d.value === Int16(-314)
    @test d.exp === Int16(-2)
end

@testset "comparisons" begin
    @test DecimalNumbers.Decimal(1) == DecimalNumbers.Decimal(1)
    @test DecimalNumbers.Decimal(1) != DecimalNumbers.Decimal(10)
    @test DecimalNumbers.Decimal(1, -1) != DecimalNumbers.Decimal(10)
    @test DecimalNumbers.Decimal(1, -1) == DecimalNumbers.Decimal(1, -1)
    @test DecimalNumbers.Decimal(1, -2) < DecimalNumbers.Decimal(1, -1)
    @test DecimalNumbers.Decimal(1) < DecimalNumbers.Decimal(2)
    # denormalized
    a = DecimalNumbers.Decimal(10, 1)
    b = DecimalNumbers.Decimal(100, 0)
    @test a == b
    @test !(a < b)
    @test !(b < a)
end

@testset "parse" begin
    @test parse(DecimalNumbers.Decimal{Int64}, "-101") == DecimalNumbers.Decimal(-101)
    @test parse(DecimalNumbers.Decimal{Int64}, "101") == DecimalNumbers.Decimal(101)
    @test parse(DecimalNumbers.Decimal{Int64}, "101.") == DecimalNumbers.Decimal(101)
    @test parse(DecimalNumbers.Decimal{Int64}, "101.0") == DecimalNumbers.Decimal(101)
    @test parse(DecimalNumbers.Decimal{Int64}, "1.01") == DecimalNumbers.Decimal(101, -2)
    @test parse(DecimalNumbers.Decimal{Int64}, ".101") == DecimalNumbers.Decimal(101, -3)
    @test parse(DecimalNumbers.Decimal{Int64}, "0.101") == DecimalNumbers.Decimal(101, -3)
    @test parse(DecimalNumbers.Decimal{Int64}, "0.0101") == DecimalNumbers.Decimal(101, -4)
end

@testset "show" begin
    @test string( DecimalNumbers.Decimal(101, 3)) == "dec\"101000.0\""
    @test string( DecimalNumbers.Decimal(101, 2)) == "dec\"10100.0\""
    @test string( DecimalNumbers.Decimal(101, 1)) == "dec\"1010.0\""
    @test string( DecimalNumbers.Decimal(-101)) == "dec\"-101.0\""
    @test string( DecimalNumbers.Decimal(101)) == "dec\"101.0\""
    @test string( DecimalNumbers.Decimal(101, 0)) == "dec\"101.0\""
    @test string( DecimalNumbers.Decimal(101, -2)) == "dec\"1.01\""
    @test string( DecimalNumbers.Decimal(101, -3)) == "dec\"0.101\""
    @test string( DecimalNumbers.Decimal(101, -4)) == "dec\"0.0101\""
end

@testset "math" begin
    local T, xD, x, i
    try
        for T in (Int8, Int16, Int32, Int64, Int128)
            xD = DecimalNumbers.Decimal(T(0))
            x = T(0)
            for i in rand(T, 10)
                @test abs(DecimalNumbers.Decimal(i)) == abs(i)
                @test DecimalNumbers.Decimal(i) + xD == i + x
                @test DecimalNumbers.Decimal(i) - xD == i - x
                @test DecimalNumbers.Decimal(widen(i)) * DecimalNumbers.Decimal(widen(i)) == widen(i) * widen(i)
                xD += DecimalNumbers.Decimal(i)
                x += i
            end
        end
    catch e
        @show T, xD, x, i
        rethrow(e)
    end

    @test DecimalNumbers.Decimal(1) + DecimalNumbers.Decimal(1) == DecimalNumbers.Decimal(2)
    @test DecimalNumbers.Decimal(10) + DecimalNumbers.Decimal(1) == DecimalNumbers.Decimal(11)
    @test DecimalNumbers.Decimal(10, 2) + DecimalNumbers.Decimal(1, -1) == DecimalNumbers.Decimal(10001, -1)
    @test DecimalNumbers.Decimal(1, -1) + DecimalNumbers.Decimal(2, -1) == DecimalNumbers.Decimal(3, -1)
    @test DecimalNumbers.Decimal(1) - DecimalNumbers.Decimal(1) == DecimalNumbers.Decimal(0)
    @test DecimalNumbers.Decimal(1) * DecimalNumbers.Decimal(1) == DecimalNumbers.Decimal(1)
    @test DecimalNumbers.Decimal(10) * DecimalNumbers.Decimal(1, -1) == DecimalNumbers.Decimal(1)
    @test DecimalNumbers.Decimal(1) / DecimalNumbers.Decimal(1) == DecimalNumbers.Decimal(1)
    @test DecimalNumbers.Decimal(10) / DecimalNumbers.Decimal(1) == DecimalNumbers.Decimal(10)
    @test DecimalNumbers.Decimal(-10) / DecimalNumbers.Decimal(1) == DecimalNumbers.Decimal(-10)
    @test DecimalNumbers.Decimal(1) / DecimalNumbers.Decimal(1.5) == DecimalNumbers.Decimal(66666666666666667, -17)
    @test DecimalNumbers.Decimal(1) / DecimalNumbers.Decimal(0.5) == DecimalNumbers.Decimal(2)

    # division
    # Int8
    @test DecimalNumbers.Decimal(Int8(22)) / DecimalNumbers.Decimal(Int8(7)) == DecimalNumbers.Decimal(31, -1)
    # Int16
    @test DecimalNumbers.Decimal(Int16(22)) / DecimalNumbers.Decimal(Int16(7)) == DecimalNumbers.Decimal(3143, -3)
    # Int32
    @test DecimalNumbers.Decimal(Int32(22)) / DecimalNumbers.Decimal(Int32(7)) == DecimalNumbers.Decimal(314285714, -8)
    # Int64
    @test DecimalNumbers.Decimal(Int64(22)) / DecimalNumbers.Decimal(Int64(7)) == DecimalNumbers.Decimal(314285714285714286, -17)
    # Int128
    @test DecimalNumbers.Decimal(Int128(22)) / DecimalNumbers.Decimal(Int128(7)) == DecimalNumbers.Decimal(31428571428571428571428571428571428571, -37)
end